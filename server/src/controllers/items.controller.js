const itemsService = require("../services/items.service");

async function list(req, res, next) {
  try {
    res.json({ items: await itemsService.listItems(req.auth.sub, req.query.folderId) });
  } catch (error) {
    next(error);
  }
}

async function create(req, res, next) {
  try {
    const item = await itemsService.createItem(req.auth.sub, req.body);
    res.status(201).json({ item });
  } catch (error) {
    next(error);
  }
}

module.exports = { list, create };
