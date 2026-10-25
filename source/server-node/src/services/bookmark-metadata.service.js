const dns = require("node:dns").promises;
const http = require("node:http");
const https = require("node:https");
const net = require("node:net");
const BookmarkError = require("./bookmark-errors");

const MAX_BYTES = 1024 * 1024;
const MAX_REDIRECTS = 4;
const TIMEOUT_MS = 6000;

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

function parseMetadata(html, finalUrl) {
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
  const image = values.get("og:image") || values.get("og:image:url") ||
    values.get("twitter:image") || values.get("twitter:image:src");
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
    const request = requestImpl(url, {
      headers: { Accept: "text/html,application/xhtml+xml", "User-Agent": "wwjing-bookmark-metadata/1.0" },
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

function createMetadataService(dependencies = {}) {
  const resolver = dependencies.lookup || dns.lookup;
  const requestImpl = dependencies.request || ((url, options, callback) =>
    (url.protocol === "https:" ? https : http).request(url, options, callback));
  return async function fetchMetadata(input = {}) {
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
      return parseMetadata(await readBody(response), url.toString());
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
