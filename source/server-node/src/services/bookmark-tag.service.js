const model = require("../models/bookmark-tag.model");
const BookmarkError = require("./bookmark-errors");

function spaceOf(value) {
  const space = value || "star";
  if (!['star', 'cookie'].includes(space)) throw new BookmarkError(400, "INVALID_SPACE", "space 必须是 star 或 cookie");
  return space;
}

function id(value) {
  if (!/^\d+$/.test(String(value))) throw new BookmarkError(400, "INVALID_INPUT", "id 必须是有效标识");
  return String(value);
}

function parseTagIds(value) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.some((entry) => !/^\d+$/.test(String(entry)))) {
    throw new BookmarkError(400, "INVALID_INPUT", "tagIds 必须是标签标识数组");
  }
  return [...new Set(value.map(String))];
}

function name(value) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > 80) throw new BookmarkError(400, "INVALID_INPUT", "标签名称必须为 1 至 80 个字符");
  return value.trim();
}

async function list(userId, input = {}) { return model.list(userId, spaceOf(input.space)); }
async function create(userId, input = {}) { return model.create(userId, spaceOf(input.space), name(input.name)); }
async function update(userId, tagId, input = {}) { return model.update(userId, id(tagId), spaceOf(input.space), name(input.name)); }
async function remove(userId, tagId, input = {}) {
  if (!await model.remove(userId, id(tagId), spaceOf(input.space))) throw new BookmarkError(404, "TAG_NOT_FOUND", "标签不存在");
}

module.exports = { list, create, update, remove, spaceOf, parseTagIds };
