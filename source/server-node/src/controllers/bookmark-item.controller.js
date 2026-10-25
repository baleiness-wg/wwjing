const itemService = require("../services/bookmark-item.service");
const logger = require("../logger");

async function list(req, res, next) {
  try {
    res.json(await itemService.list(req.auth.sub, req.query));
  } catch (error) {
    next(error);
  }
}

async function create(req, res, next) {
  try {
    const item = await itemService.create(req.auth.sub, req.body);
    (req.log || logger).info({ userId: req.auth.sub, itemId: item.id }, "bookmark item created");
    res.status(201).json({ item });
  } catch (error) {
    next(error);
  }
}

async function get(req, res, next) {
  try {
    res.json({ item: await itemService.get(req.auth.sub, req.params.id) });
  } catch (error) {
    next(error);
  }
}

async function update(req, res, next) {
  try {
    const item = await itemService.update(req.auth.sub, req.params.id, req.body);
    (req.log || logger).info({ userId: req.auth.sub, itemId: item.id }, "bookmark item updated");
    res.json({ item });
  } catch (error) {
    next(error);
  }
}

async function remove(req, res, next) {
  try {
    await itemService.remove(req.auth.sub, req.params.id);
    (req.log || logger).info({ userId: req.auth.sub, itemId: req.params.id }, "bookmark item deleted");
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

module.exports = { list, create, get, update, remove };
