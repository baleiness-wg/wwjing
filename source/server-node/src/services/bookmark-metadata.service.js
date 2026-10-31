const dns = require("node:dns").promises;
const http = require("node:http");
const https = require("node:https");
const net = require("node:net");
const BookmarkError = require("./bookmark-errors");

const MAX_BYTES = 1024 * 1024;
const MAX_REDIRECTS = 4;
const TIMEOUT_MS = 10000;

function parseIpv4(address) {
  if (net.isIP(address) !== 4) return null;
  return address.split(".").map(Number);
}

function parseIpv6(address) {
  const zoneIndex = address.indexOf("%");
  const value = (zoneIndex === -1 ? address : address.slice(0, zoneIndex)).toLowerCase();
  if (net.isIP(value) !== 6) return null;
  const halves = value.split("::");
  const expand = (part) => {
    if (!part) return [];
    const words = part.split(":");
    const last = words.at(-1);
    if (last && last.includes(".")) {
      const bytes = parseIpv4(last);
      words.splice(-1, 1, ((bytes[0] << 8) | bytes[1]).toString(16),
        ((bytes[2] << 8) | bytes[3]).toString(16));
    }
    return words.map((word) => parseInt(word, 16));
  };
  const left = expand(halves[0]);
  const right = expand(halves[1]);
  return halves.length === 1
    ? left
    : [...left, ...Array(8 - left.length - right.length).fill(0), ...right];
}

function isPublicAddress(address) {
  const ipv4 = parseIpv4(address);
  if (ipv4) {
    const [a, b, c] = ipv4;
    return !(a === 0 || a === 10 || a === 127 ||
      (a === 100 && b >= 64 && b <= 127) ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 0 && c === 0) ||
      (a === 192 && b === 0 && c === 2) ||
      (a === 192 && b === 168) ||
      (a === 198 && (b === 18 || b === 19)) ||
      (a === 198 && b === 51 && c === 100) ||
      (a === 203 && b === 0 && c === 113) || a >= 224);
  }
  const words = parseIpv6(address);
  if (!words) return false;
  if (words.slice(0, 5).every((word) => word === 0) && words[5] === 0xffff) {
    return isPublicAddress(`${words[6] >> 8}.${words[6] & 255}.${words[7] >> 8}.${words[7] & 255}`);
  }
  const allZero = words.every((word) => word === 0);
  const loopback = words.slice(0, 7).every((word) => word === 0) && words[7] === 1;
  const uniqueLocal = (words[0] & 0xfe00) === 0xfc00;
  const linkLocal = (words[0] & 0xffc0) === 0xfe80;
  const multicast = (words[0] & 0xff00) === 0xff00;
  return !(allZero || loopback || uniqueLocal || linkLocal || multicast);
}

function parseHttpUrl(value, code = "INVALID_METADATA_URL") {
  if (typeof value !== "string" || !value.trim()) {
    throw new BookmarkError(400, code, "链接必须是有效的 HTTP 或 HTTPS URL");
  }
  try {
    const url = new URL(value.trim());
    if (!["http:", "https:"].includes(url.protocol) || !url.hostname || url.username || url.password) {
      throw new Error();
    }
    return url;
  } catch {
    throw new BookmarkError(400, code, "链接必须是有效的 HTTP 或 HTTPS URL");
  }
}

async function resolvePublic(url, resolver) {
  const literal = net.isIP(url.hostname) ? [{ address: url.hostname, family: net.isIP(url.hostname) }] :
    await resolver(url.hostname, { all: true, verbatim: true });
  if (!literal.length || literal.some(({ address }) => !isPublicAddress(address))) {
    throw new BookmarkError(400, "METADATA_TARGET_BLOCKED", "目标地址不是公开网络地址");
  }
  return literal;
}

function withTimeout(promise, timeoutMs) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() =>
      reject(new BookmarkError(504, "METADATA_TIMEOUT", "元数据请求超时")), timeoutMs);
    promise.then(
      (value) => { clearTimeout(timer); resolve(value); },
      (error) => { clearTimeout(timer); reject(error); }
    );
  });
}

function decodeHtml(value) {
  if (!value) return null;
  const named = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " };
  return value.replace(/&(#(?:x[0-9a-f]+|\d+)|[a-z]+);/gi, (entity, key) => {
    if (key[0] !== "#") return named[key.toLowerCase()] ?? entity;
    const hex = key[1].toLowerCase() === "x";
    const point = parseInt(key.slice(hex ? 2 : 1), hex ? 16 : 10);
    try { return String.fromCodePoint(point); } catch { return entity; }
  }).replace(/\s+/g, " ").trim() || null;
}

function attributes(tag) {
  const result = {};
  const pattern = /([^\s=/>]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/g;
  let match;
  while ((match = pattern.exec(tag))) result[match[1].toLowerCase()] = match[2] ?? match[3] ?? match[4];
  return result;
}

function decodeEmbeddedUrl(value) {
  return value
    .replace(/\\u002f/gi, "/")
    .replace(/\\\//g, "/")
    .replace(/\\u0026/gi, "&")
    .replace(/\\u003d/gi, "=")
    .replace(/\\u003f/gi, "?");
}

function embeddedCoverUrl(html, finalUrl) {
  const host = new URL(finalUrl).hostname.replace(/^www\./i, "");
  if (!/^(?:douyin|iesdouyin)\.com$/i.test(host) &&
      !/\.douyinvod\.com$/i.test(host)) return null;

  const fieldPatterns = [
    /["'](?:cover|dynamic_cover|origin_cover|thumbnail)["']\s*:\s*["']([^"']+)["']/gi,
    /["'](?:cover|dynamic_cover|origin_cover|thumbnail)["']\s*:\s*\{[\s\S]{0,800}?["']url_list["']\s*:\s*\[["']([^"']+)["']/gi,
    /["']url_list["']\s*:\s*\[["']([^"']+)["']/gi
  ];
  for (const fieldPattern of fieldPatterns) for (const match of html.matchAll(fieldPattern)) {
    try {
      const candidate = new URL(decodeEmbeddedUrl(match[1]), finalUrl);
      if (["http:", "https:"].includes(candidate.protocol) &&
          candidate.hostname && (!net.isIP(candidate.hostname) || isPublicAddress(candidate.hostname))) {
        return candidate.toString();
      }
    } catch {
      // Ignore malformed embedded candidates and continue to the next image.
    }
  }
  return null;
}

function cleanCoverUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== "string") return null;
  let str = rawUrl.trim();
  try {
    // 递归进行最多 3 次 decodeURIComponent 处理嵌套转义
    for (let i = 0; i < 3; i++) {
      if (str.includes("%3A") || str.includes("%2F") || str.includes("%3a") || str.includes("%2f")) {
        str = decodeURIComponent(str);
      } else {
        break;
      }
    }
  } catch {
    // ignore decode errors
  }

  // 小红书图片清洗：精准匹配末尾真实的 sns-webpic 或 sns-img 直链，彻底丢弃前置反代前缀
  const xhsMatch = str.match(/https?:\/\/(sns-(?:webpic|img)[^"'?\s<]+(?:\?[^"'?\s<]*)?)/i);
  if (xhsMatch) {
    return `https://${xhsMatch[1]}`;
  }

  // 若仍存在多重协议嵌套（例如 proxy/https://...），截取最后一段合法的 http:// 或 https://
  const lastHttps = str.lastIndexOf("https://");
  const lastHttp = str.lastIndexOf("http://");
  const lastProtocolIndex = Math.max(lastHttps, lastHttp);
  if (lastProtocolIndex > 0) {
    str = str.slice(lastProtocolIndex).replace(/^http:\/\//i, "https://");
  }
  return str;
}

function parseMetadata(html, finalUrl) {
  const embeddedCover = embeddedCoverUrl(html, finalUrl);
  const document = html
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/<script\b[\s\S]*?<\/script\s*>/gi, "")
    .replace(/<style\b[\s\S]*?<\/style\s*>/gi, "");
  const values = new Map();
  for (const match of document.matchAll(/<meta\b[^>]*>/gi)) {
    const attrs = attributes(match[0]);
    const key = (attrs.property || attrs.name || "").toLowerCase();
    if (key && attrs.content !== undefined && !values.has(key)) values.set(key, decodeHtml(attrs.content));
  }
  const titleTag = document.match(/<title\b[^>]*>([\s\S]*?)<\/title\s*>/i);
  const title = values.get("og:title") || values.get("twitter:title") ||
    decodeHtml(titleTag?.[1]?.replace(/<[^>]*>/g, ""));
  const description = values.get("og:description") || values.get("twitter:description") ||
    values.get("description") || null;
  let image = values.get("og:image") || values.get("og:image:url") ||
    values.get("twitter:image") || values.get("twitter:image:src") || embeddedCover;
  if (image) {
    image = cleanCoverUrl(image);
  }
  let coverUrl = null;
  if (image) {
    try {
      const candidate = new URL(image, finalUrl);
      if (["http:", "https:"].includes(candidate.protocol) && candidate.hostname &&
          (!net.isIP(candidate.hostname) || isPublicAddress(candidate.hostname))) {
        coverUrl = candidate.toString();
      }
    } catch {
      coverUrl = null;
    }
  }
  return { finalUrl, title: title || null, description, coverUrl };
}

function requestPage(url, addresses, requestImpl, timeoutMs) {
  return new Promise((resolve, reject) => {
    let settled = false;
    const fail = (error) => {
      if (settled) return;
      settled = true;
      reject(error);
    };

    const isBili = url.hostname.toLowerCase().endsWith("bilibili.com");
    const referer = isBili ? "https://www.bilibili.com/" : "https://www.douyin.com/";
    const userAgent = isBili
      ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
      : "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36";

    const request = requestImpl(url, {
      headers: {
        Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Cache-Control": "no-cache",
        Referer: referer,
        "User-Agent": userAgent
      },
      lookup(hostname, options, callback) {
        const candidates = addresses.filter(({ family }) => !options.family || family === options.family);
        if (options.all) return callback(null, candidates);
        const selected = candidates[0] || addresses[0];
        callback(null, selected.address, selected.family);
      }
    }, (response) => {
      if (settled) return response.resume();
      settled = true;
      resolve(response);
    });
    request.on("error", fail);
    request.setTimeout(timeoutMs, () => {
      request.destroy(new BookmarkError(504, "METADATA_TIMEOUT", "元数据请求超时"));
    });
    request.end();
  });
}

async function readBody(response) {
  const chunks = [];
  let size = 0;
  for await (const chunk of response) {
    size += chunk.length;
    if (size > MAX_BYTES) {
      response.destroy();
      throw new BookmarkError(413, "METADATA_TOO_LARGE", "页面内容超过 1 MB 限制");
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}

function resolveBilibiliData(finalUrl) {
  try {
    const url = new URL(finalUrl);
    const host = url.hostname.toLowerCase();
    if (!host.endsWith("bilibili.com") && !host.endsWith("b23.tv")) return null;

    return new Promise((resolve) => {
      // 提取视频 ID (BV 或 av 号)
      let bvid = null;
      let aid = null;
      const bvMatch = url.pathname.match(/\/(?:video\/)?(BV[a-zA-Z0-9]+)/i);
      if (bvMatch) {
        bvid = bvMatch[1];
      } else {
        const avMatch = url.pathname.match(/\/(?:video\/)?av(\d+)/i);
        if (avMatch) aid = avMatch[1];
      }

      // 如果有直接的 bvid/aid，直接请求 Bilibili 官方开放 API (view 接口)，最权威、最秒级、无第三方依赖！
      if (bvid || aid) {
        callOfficialView(bvid, aid);
        return;
      }

      // 否则尝试专用解析接口
      callBugpk();

      function callOfficialView(bv, av) {
        const param = bv ? `bvid=${encodeURIComponent(bv)}` : `aid=${encodeURIComponent(av)}`;
        const apiUrl = `https://api.bilibili.com/x/web-interface/view?${param}`;
        const req = https.get(apiUrl, {
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            Referer: "https://www.bilibili.com/"
          },
          timeout: 4000
        }, (res) => {
          let data = "";
          res.on("data", (chunk) => data += chunk);
          res.on("end", () => {
            try {
              const json = JSON.parse(data);
              const d = json.data;
              if (d && d.pic) {
                const pic = typeof d.pic === "string" && !d.pic.includes("transparent.png")
                  ? d.pic.replace(/^http:\/\//i, "https://")
                  : null;
                resolve({
                  title: d.title || null,
                  description: d.desc || null,
                  coverUrl: pic
                });
                return;
              }
            } catch {
              // fallback
            }
            callBugpk();
          });
        });
        req.on("error", () => callBugpk());
        req.on("timeout", () => {
          req.destroy();
          callBugpk();
        });
      }

      function callBugpk() {
        const bugpkUrl = `https://api.bugpk.com/api/bilibili?url=${encodeURIComponent(finalUrl)}`;
        const bugpkReq = https.get(bugpkUrl, {
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            Accept: "application/json"
          },
          timeout: 4000
        }, (res) => {
          let raw = "";
          res.on("data", (chunk) => raw += chunk);
          res.on("end", () => {
            try {
              const parsed = JSON.parse(raw);
              if (parsed.code === 200 && parsed.data && parsed.data.cover) {
                const cover = String(parsed.data.cover).replace(/^http:\/\//i, "https://");
                resolve({
                  title: parsed.data.title || null,
                  description: parsed.data.description || null,
                  coverUrl: cover
                });
                return;
              }
            } catch {
              // ignore
            }
            resolve(null);
          });
        });

        bugpkReq.on("error", () => resolve(null));
        bugpkReq.on("timeout", () => {
          bugpkReq.destroy();
          resolve(null);
        });
      }
    });
  } catch {
    return null;
  }
}

function resolveDouyinData(finalUrl) {
  try {
    const url = new URL(finalUrl);
    const host = url.hostname.toLowerCase();
    if (!host.endsWith("douyin.com")) return null;

    return new Promise((resolve) => {
      const bugpkUrl = `https://api.bugpk.com/api/douyin?url=${encodeURIComponent(finalUrl)}`;
      const req = https.get(bugpkUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          Accept: "application/json"
        },
        timeout: 8000
      }, (res) => {
        let raw = "";
        res.on("data", (chunk) => raw += chunk);
        res.on("end", () => {
          try {
            const parsed = JSON.parse(raw);
            if (parsed.code === 200 && parsed.data && parsed.data.cover) {
              const cover = String(parsed.data.cover).replace(/^http:\/\//i, "https://");
              resolve({
                title: parsed.data.title || parsed.data.desc || null,
                description: parsed.data.desc || null,
                coverUrl: cover
              });
              return;
            }
          } catch {
            // ignore
          }
          resolve(null);
        });
      });

      req.on("error", () => resolve(null));
      req.on("timeout", () => {
        req.destroy();
        resolve(null);
      });
    });
  } catch {
    return null;
  }
}

function createMetadataService(dependencies = {}) {
  const resolver = dependencies.lookup || dns.lookup;
  const requestImpl = dependencies.request || ((url, options, callback) =>
    (url.protocol === "https:" ? https : http).request(url, options, callback));
  return async function fetchMetadata(input = {}) {
    const originalRawUrl = input.sourceUrl?.trim() || "";
    // 如果是抖音短链或直链，提前并发发起专用解析，不用死等 HTML 慢响应
    const douyinPromise = (originalRawUrl.includes("douyin.com"))
      ? resolveDouyinData(originalRawUrl)
      : null;

    let url = parseHttpUrl(input.sourceUrl);
    const deadline = Date.now() + (dependencies.timeoutMs || TIMEOUT_MS);
    for (let redirects = 0; ; redirects += 1) {
      const remaining = deadline - Date.now();
      if (remaining <= 0) throw new BookmarkError(504, "METADATA_TIMEOUT", "元数据请求超时");
      let addresses;
      try {
        addresses = await withTimeout(resolvePublic(url, resolver), remaining);
      } catch (error) {
        if (error.name === "BookmarkError") throw error;
        throw new BookmarkError(502, "METADATA_DNS_FAILED", "无法解析元数据目标地址");
      }
      let response;
      try {
        response = await requestPage(url, addresses, requestImpl, Math.max(1, deadline - Date.now()));
      } catch (error) {
        if (error.name === "BookmarkError") throw error;
        throw new BookmarkError(502, "METADATA_FETCH_FAILED", "无法获取页面元数据");
      }
      if ([301, 302, 303, 307, 308].includes(response.statusCode) && response.headers.location) {
        response.resume();
        if (redirects >= MAX_REDIRECTS) {
          throw new BookmarkError(502, "METADATA_REDIRECT_LIMIT", "页面重定向次数过多");
        }
        url = parseHttpUrl(new URL(response.headers.location, url).toString(), "INVALID_METADATA_REDIRECT");
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        response.resume();
        throw new BookmarkError(502, "METADATA_FETCH_FAILED", `页面返回 HTTP ${response.statusCode}`);
      }
      const contentType = String(response.headers["content-type"] || "").toLowerCase();
      if (!/^\s*(text\/html|application\/xhtml\+xml)(?:\s*;|\s*$)/.test(contentType)) {
        response.resume();
        throw new BookmarkError(415, "METADATA_UNSUPPORTED_CONTENT", "目标内容不是 HTML 页面");
      }
      const metadata = parseMetadata(await readBody(response), url.toString());
      if (url.hostname.toLowerCase().endsWith("bilibili.com") || url.hostname.toLowerCase().endsWith("b23.tv")) {
        const biliData = await resolveBilibiliData(url.toString());
        if (biliData) {
          if (biliData.coverUrl && (!metadata.coverUrl || metadata.coverUrl.includes("transparent.png"))) {
            metadata.coverUrl = biliData.coverUrl;
          }
          if (biliData.title && !metadata.title) {
            metadata.title = biliData.title;
          }
          if (biliData.description && !metadata.description) {
            metadata.description = biliData.description;
          }
        }
      } else if (url.hostname.toLowerCase().endsWith("douyin.com") || originalRawUrl.includes("douyin.com")) {
        const dyData = (await douyinPromise) || (await resolveDouyinData(url.toString()));
        if (dyData) {
          if (dyData.coverUrl && !metadata.coverUrl) {
            metadata.coverUrl = dyData.coverUrl;
          }
          if (dyData.title && !metadata.title) {
            metadata.title = dyData.title;
          }
          if (dyData.description && !metadata.description) {
            metadata.description = dyData.description;
          }
        }
      }
      return metadata;
    }
  };
}

module.exports = {
  fetchMetadata: createMetadataService(),
  createMetadataService,
  decodeHtml,
  isPublicAddress,
  parseMetadata
};
