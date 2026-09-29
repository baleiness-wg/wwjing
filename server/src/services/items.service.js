const itemsModel = require("../models/items.model");
const foldersModel = require("../models/folders.model");

function listItems(userId, folderId) {
  return itemsModel.findAll(userId, folderId || null);
}

async function createItem(userId, input = {}) {
  if (!input.title || !input.title.trim()) {
    const error = new Error("标题不能为空");
    error.status = 400;
    throw error;
  }

  const folderId = input.folderId || (await foldersModel.getOrCreateDefault(userId)).id;
  return itemsModel.create(userId, {
    title: input.title.trim(),
    sourceUrl: input.sourceUrl || "",
    nextAction: input.nextAction || "",
    category: input.category || "text",
    folderId
  });
}

module.exports = { listItems, createItem };
