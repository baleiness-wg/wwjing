const itemsModel = require("../models/items.model");

function listItems(userId) {
  return itemsModel.findAll(userId);
}

function createItem(userId, input = {}) {
  if (!input.title || !input.title.trim()) {
    const error = new Error("标题不能为空");
    error.status = 400;
    throw error;
  }

  return itemsModel.create(userId, {
    title: input.title.trim(),
    sourceUrl: input.sourceUrl || "",
    nextAction: input.nextAction || ""
  });
}

module.exports = { listItems, createItem };
