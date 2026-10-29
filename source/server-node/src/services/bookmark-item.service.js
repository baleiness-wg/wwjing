const itemModel = require("../models/bookmark-item.model");
const folderModel = require("../models/bookmark-folder.model");
const BookmarkError = require("./bookmark-errors");
const tagService = require("./bookmark-tag.service");

const trackingParameters = new Set([
  "fbclid", "gclid", "dclid", "msclkid", "igshid", "mc_cid", "mc_eid"
]);

function parseSpace(value) {
  const space = value || "star";
  if (!['star', 'cookie'].includes(space)) {
    throw new BookmarkError(400, "INVALID_SPACE", "space 必须是 star 或 cookie");
  }
  return space;
}

function normalizeUrl(value) {
  if (typeof value !== "string" || !value.trim()) {
    throw new BookmarkError(400, "INVALID_URL", "链接必须是有效的 HTTP 或 HTTPS URL");
  }
  let url;
  try {
    url = new URL(value.trim());
  } catch {
    throw new BookmarkError(400, "INVALID_URL", "链接必须是有效的 HTTP 或 HTTPS URL");
  }
  if (!['http:', 'https:'].includes(url.protocol) || !url.hostname) {
    throw new BookmarkError(400, "INVALID_URL", "链接必须是有效的 HTTP 或 HTTPS URL");
  }
  url.protocol = url.protocol.toLowerCase();
  url.hostname = url.hostname.toLowerCase();
  url.hash = "";
  if ((url.protocol === "http:" && url.port === "80") ||
      (url.protocol === "https:" && url.port === "443")) url.port = "";
  for (const key of [...url.searchParams.keys()]) {
    const lowerKey = key.toLowerCase();
    if (lowerKey.startsWith("utm_") || trackingParameters.has(lowerKey)) {
      url.searchParams.delete(key);
    }
  }
  url.searchParams.sort();
  if (url.pathname.length > 1) url.pathname = url.pathname.replace(/\/+$/, "");
  return { normalizedUrl: url.toString(), sourceHost: url.hostname };
}

function parseId(value, field) {
  if (!/^\d+$/.test(String(value)) || Number(value) < 1) {
    throw new BookmarkError(400, "INVALID_INPUT", `${field} 必须是有效标识`);
  }
  return String(value);
}

function optionalText(value, field) {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value !== "string") {
    throw new BookmarkError(400, "INVALID_INPUT", `${field} 必须是字符串`);
  }
  return value.trim() || null;
}

function optionalUrl(value, field) {
  const text = optionalText(value, field);
  if (text === null) return null;
  try {
    const url = new URL(text);
    if (!["http:", "https:"].includes(url.protocol) || !url.hostname) throw new Error();
    return url.toString();
  } catch {
    throw new BookmarkError(400, "INVALID_URL", `${field} 必须是有效的 HTTP 或 HTTPS URL`);
  }
}

async function validateFolder(userId, folderId, space = "star") {
  if (folderId === null || folderId === undefined) return null;
  const id = parseId(folderId, "folderId");
  if (!await folderModel.findById(userId, id, space)) {
    throw new BookmarkError(404, "FOLDER_NOT_FOUND", "收藏夹不存在");
  }
  return id;
}

async function list(userId, input = {}) {
  if (input.folderId !== undefined && input.uncategorized === "true") {
    throw new BookmarkError(400, "INVALID_INPUT", "folderId 与 uncategorized 不能同时使用");
  }
  const space = parseSpace(input.space);
  const folderId = input.folderId === undefined ? null : await validateFolder(userId, input.folderId, space);
  const page = input.page === undefined ? 1 : Number(input.page);
  const pageSize = input.pageSize === undefined ? 20 : Number(input.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    throw new BookmarkError(400, "INVALID_INPUT", "page 和 pageSize 必须是有效的分页参数");
  }
  const query = typeof input.query === "string" ? input.query.trim() : "";
  const result = await itemModel.list(userId, {
    folderId,
    space,
    includeDescendants: input.includeDescendants === "true",
    uncategorized: input.uncategorized === "true",
    query,
    page,
    pageSize
  });
  return { ...result, page, pageSize };
}

async function get(userId, idValue, space = "star") {
  const item = await itemModel.findById(userId, parseId(idValue, "id"), space);
  if (!item) throw new BookmarkError(404, "ITEM_NOT_FOUND", "收藏条目不存在");
  return item;
}

async function create(userId, input = {}) {
  const space = parseSpace(input.space);
  const sourceUrl = typeof input.sourceUrl === "string" ? input.sourceUrl.trim() : input.sourceUrl;
  const normalized = normalizeUrl(sourceUrl);
  const folderId = await validateFolder(userId, input.folderId, space);
  const duplicate = await itemModel.findDuplicate(userId, normalized.normalizedUrl, space);
  if (duplicate && input.allowDuplicate !== true) {
    throw new BookmarkError(409, "DUPLICATE_BOOKMARK", "该链接已收藏", { duplicate });
  }
  const item = await itemModel.create(userId, {
    space,
    folderId,
    title: optionalText(input.title, "title"),
    description: optionalText(input.description, "description"),
    coverUrl: optionalUrl(input.coverUrl, "coverUrl"),
    sourceUrl,
    ...normalized
  });
  if (Object.hasOwn(input, "tagIds")) await itemModel.setTags(userId, item.id, space, tagService.parseTagIds(input.tagIds));
  return item;
}

async function update(userId, idValue, input = {}) {
  const space = parseSpace(input.space);
  const id = parseId(idValue, "id");
  const current = await get(userId, id, space);
  const sourceUrl = Object.hasOwn(input, "sourceUrl") ? input.sourceUrl : current.sourceUrl;
  const normalized = normalizeUrl(sourceUrl);
  const folderId = Object.hasOwn(input, "folderId")
    ? await validateFolder(userId, input.folderId, space)
    : current.folderId;
  const item = await itemModel.update(userId, id, {
    folderId,
    title: Object.hasOwn(input, "title") ? optionalText(input.title, "title") : current.title,
    description: Object.hasOwn(input, "description")
      ? optionalText(input.description, "description") : current.description,
    coverUrl: Object.hasOwn(input, "coverUrl")
      ? optionalUrl(input.coverUrl, "coverUrl") : current.coverUrl,
    sourceUrl: sourceUrl.trim(),
    ...normalized
  });
  if (Object.hasOwn(input, "tagIds")) await itemModel.setTags(userId, id, space, tagService.parseTagIds(input.tagIds));
  return item;
}

async function remove(userId, idValue) {
  const id = parseId(idValue, "id");
  if (!await itemModel.remove(userId, id)) {
    throw new BookmarkError(404, "ITEM_NOT_FOUND", "收藏条目不存在");
  }
}

module.exports = { normalizeUrl, list, get, create, update, remove, parseSpace };
