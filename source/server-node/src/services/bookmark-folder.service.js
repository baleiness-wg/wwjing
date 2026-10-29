const folderModel = require("../models/bookmark-folder.model");
const BookmarkError = require("./bookmark-errors");

const maxDepth = 8;

function parseSpace(value) {
  const space = value || "star";
  if (!['star', 'cookie'].includes(space)) {
    throw new BookmarkError(400, "INVALID_SPACE", "space 必须是 star 或 cookie");
  }
  return space;
}

function parseId(value, field) {
  if (!/^\d+$/.test(String(value)) || Number(value) < 1) {
    throw new BookmarkError(400, "INVALID_INPUT", `${field} 必须是有效标识`);
  }
  return String(value);
}

function parseParentId(value) {
  return value === null || value === undefined ? null : parseId(value, "parentId");
}

function parseName(value) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > 120) {
    throw new BookmarkError(400, "INVALID_INPUT", "name 必须为 1 至 120 个字符");
  }
  return value.trim();
}

function parsePosition(value) {
  const position = value === undefined ? 0 : value;
  if (!Number.isInteger(position) || position < 0) {
    throw new BookmarkError(400, "INVALID_INPUT", "position 必须是非负整数");
  }
  return position;
}

async function requireFolder(userId, id, space, client, forUpdate = false) {
  const folder = await folderModel.findById(userId, id, space, client, forUpdate);
  if (!folder) throw new BookmarkError(404, "FOLDER_NOT_FOUND", "收藏夹不存在");
  return folder;
}

async function list(userId, space = "star") {
  return folderModel.listByUser(userId, parseSpace(space));
}

async function create(userId, input = {}, space = "star") {
  space = parseSpace(space);
  const name = parseName(input.name);
  const parentId = parseParentId(input.parentId);
  const position = parsePosition(input.position);
  if (parentId) {
    await requireFolder(userId, parentId, space);
    const parentDepth = await folderModel.getDepth(userId, parentId, space);
    if (parentDepth >= maxDepth) {
      throw new BookmarkError(409, "FOLDER_DEPTH_EXCEEDED", "收藏夹最多支持 8 层");
    }
  }
  return folderModel.create(userId, { name, parentId, position }, space);
}

async function update(userId, idValue, input = {}, space = "star") {
  space = parseSpace(space);
  const id = parseId(idValue, "id");
  const client = await folderModel.pool.connect();
  try {
    await client.query("BEGIN");
    const current = await requireFolder(userId, id, space, client, true);
    const values = {
      name: Object.hasOwn(input, "name") ? parseName(input.name) : current.name,
      parentId: Object.hasOwn(input, "parentId") ? parseParentId(input.parentId) : current.parentId,
      position: Object.hasOwn(input, "position") ? parsePosition(input.position) : current.position
    };

    if (values.parentId) {
      if (values.parentId === id) {
        throw new BookmarkError(409, "FOLDER_CYCLE", "收藏夹不能移动到自身或其子目录");
      }
      await requireFolder(userId, values.parentId, space, client, true);
      if (await folderModel.isDescendant(userId, id, values.parentId, space, client)) {
        throw new BookmarkError(409, "FOLDER_CYCLE", "收藏夹不能移动到自身或其子目录");
      }
      const parentDepth = await folderModel.getDepth(userId, values.parentId, space, client);
      const subtreeDepth = await folderModel.getSubtreeDepth(userId, id, space, client);
      if (parentDepth + subtreeDepth > maxDepth) {
        throw new BookmarkError(409, "FOLDER_DEPTH_EXCEEDED", "收藏夹最多支持 8 层");
      }
    }

    const folder = await folderModel.update(userId, id, values, space, client);
    await client.query("COMMIT");
    return folder;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function remove(userId, idValue, space = "star") {
  space = parseSpace(space);
  const id = parseId(idValue, "id");
  const client = await folderModel.pool.connect();
  try {
    await client.query("BEGIN");
    await requireFolder(userId, id, space, client, true);
    if (await folderModel.hasContents(userId, id, space, client)) {
      throw new BookmarkError(409, "FOLDER_NOT_EMPTY", "收藏夹非空，不能删除");
    }
    await folderModel.remove(userId, id, space, client);
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

module.exports = { list, create, update, remove, maxDepth, parseSpace };
