const favoriteDetailsModel = require("../models/favorite-details.model");

function listFavoriteDetails(userId, folderId) {
  return favoriteDetailsModel.findAll(userId, folderId || null);
}

async function createFavoriteDetail(userId, input = {}) {
  const sourceUrl = normalizeUrl(input.sourceUrl);
  const metadata = sourceUrl ? await readMetadata(sourceUrl) : {};
  const title = (input.title || metadata.title || sourceUrl || "").trim();

  if (!title) {
    const error = new Error("标题或链接不能为空");
    error.status = 400;
    throw error;
  }

  return favoriteDetailsModel.create(userId, {
    title: title.slice(0, 200),
    description: (input.description || metadata.description || "").trim(),
    sourceUrl,
    nextAction: input.nextAction || "",
    category: input.category || "text",
    folderId: input.folderId || null
  });
}

function normalizeUrl(value) {
  if (!value) return "";
  let url;
  try {
    url = new URL(value.trim());
  } catch {
    const error = new Error("链接格式不正确");
    error.status = 400;
    throw error;
  }
  if (!['http:', 'https:'].includes(url.protocol)) {
    const error = new Error("只支持 http 或 https 链接");
    error.status = 400;
    throw error;
  }
  return url.toString();
}

async function readMetadata(sourceUrl) {
  try {
    const response = await fetch(sourceUrl, {
      signal: AbortSignal.timeout(8000),
      headers: { "user-agent": "WWJ/1.0 metadata reader" }
    });
    if (!response.ok) return {};
    const html = (await response.text()).slice(0, 2_000_000);
    return {
      title: readMeta(html, "og:title") || readMeta(html, "twitter:title") || readTag(html, "title"),
      description: readMeta(html, "og:description") || readMeta(html, "twitter:description") || readMeta(html, "description")
    };
  } catch {
    return {};
  }
}

function readMeta(html, name) {
  const tags = html.match(/<meta\b[^>]*>/gi) || [];
  for (const tag of tags) {
    const key = tag.match(/(?:property|name)=["']([^"']+)["']/i)?.[1];
    if (key?.toLowerCase() !== name.toLowerCase()) continue;
    return clean(tag.match(/content=["']([^"']*)["']/i)?.[1]);
  }
  return "";
}

function readTag(html, tag) {
  const match = html.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, "i"));
  return clean(match?.[1]);
}

function clean(value = "") {
  return value.replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&").replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'").replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">").replace(/\s+/g, " ").trim();
}

module.exports = { listFavoriteDetails, createFavoriteDetail };
