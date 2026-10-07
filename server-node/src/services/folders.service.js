const foldersModel = require("../models/folders.model");

function listFolders(userId) {
  return foldersModel.findAll(userId);
}

async function createFolder(userId, input = {}) {
  const name = String(input.name || "").trim();
  if (!name) {
    const error = new Error("收藏夹名称不能为空");
    error.status = 400;
    throw error;
  }
  return foldersModel.create(userId, name);
}

module.exports = { listFolders, createFolder };
