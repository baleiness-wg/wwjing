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

  const categoryFolderNames = {
    shopping: "购物收藏夹",
    article: "文章收藏夹",
    video: "视频收藏夹",
    code: "代码收藏夹"
  };
  const selectedFolder = input.folderId
    ? { id: input.folderId }
    : await foldersModel.findByName(
        userId,
        categoryFolderNames[input.category] || "默认收藏夹"
      );
  const folderId = selectedFolder?.id || (await foldersModel.getOrCreateDefault(userId)).id;
  return itemsModel.create(userId, {
    title: input.title.trim(),
    sourceUrl: input.sourceUrl || "",
    nextAction: input.nextAction || "",
    category: input.category || "text",
    folderId
  });
}

module.exports = { listItems, createItem };
