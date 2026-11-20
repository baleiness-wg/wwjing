const entryModel = require("../models/inspiration-entry.model");
const folderModel = require("../models/bookmark-folder.model");
const BookmarkError = require("./bookmark-errors");

function parseSpace(value) {
  if (!["star", "kitchen"].includes(value)) {
    throw new BookmarkError(400, "INVALID_SPACE", "space 必须是 star 或 kitchen");
  }
  return value;
}

function parseId(value) {
  if (!/^[a-f0-9]{32}$/i.test(String(value))) {
    throw new BookmarkError(400, "INVALID_INPUT", "id 必须是有效标识");
  }
  return String(value);
}

function text(value, field, required = false) {
  if (value === null || value === undefined || value === "") {
    if (required) throw new BookmarkError(400, "INVALID_INPUT", `${field} 不能为空`);
    return null;
  }
  if (typeof value !== "string") {
    throw new BookmarkError(400, "INVALID_INPUT", `${field} 必须是字符串`);
  }
  const result = value.trim();
  if (required && !result) throw new BookmarkError(400, "INVALID_INPUT", `${field} 不能为空`);
  return result || null;
}

async function folder(userId, value, space) {
  if (value === null || value === undefined || value === "") return null;
  const id = String(value);
  if (!/^[a-f0-9]{32}$/i.test(id) || !await folderModel.findById(userId, id, space)) {
    throw new BookmarkError(404, "FOLDER_NOT_FOUND", "收藏夹不存在");
  }
  return id;
}

async function list(userId, input = {}) {
  return { entries: await entryModel.list(userId, parseSpace(input.space || "star")) };
}

async function create(userId, input = {}) {
  const space = parseSpace(input.space || "star");
  return entryModel.create(userId, {
    space,
    folderId: await folder(userId, input.folderId, space),
    title: text(input.title, "title"),
    content: text(input.content, "content", true)
  });
}

async function update(userId, idValue, input = {}) {
  const space = parseSpace(input.space || "star");
  const entry = await entryModel.update(userId, parseId(idValue), {
    space,
    folderId: await folder(userId, input.folderId, space),
    title: text(input.title, "title"),
    content: text(input.content, "content", true)
  });
  if (!entry) throw new BookmarkError(404, "INSPIRATION_NOT_FOUND", "灵感不存在");
  return entry;
}

async function remove(userId, idValue, spaceValue) {
  const removed = await entryModel.remove(userId, parseId(idValue), parseSpace(spaceValue || "star"));
  if (!removed) throw new BookmarkError(404, "INSPIRATION_NOT_FOUND", "灵感不存在");
}

module.exports = { list, create, update, remove };
