const folderService = require("../services/bookmark-folder.service");
const logger = require("../logger");

async function list(req, res, next) {
  try {
    res.json({ folders: await folderService.list(req.auth.sub) });
  } catch (error) {
    next(error);
  }
}

async function create(req, res, next) {
  try {
    const folder = await folderService.create(req.auth.sub, req.body);
    (req.log || logger).info({ userId: req.auth.sub, folderId: folder.id }, "bookmark folder created");
    res.status(201).json({ folder });
  } catch (error) {
    next(error);
  }
}

async function update(req, res, next) {
  try {
    const folder = await folderService.update(req.auth.sub, req.params.id, req.body);
    (req.log || logger).info({ userId: req.auth.sub, folderId: folder.id }, "bookmark folder updated");
    res.json({ folder });
  } catch (error) {
    next(error);
  }
}

async function remove(req, res, next) {
  try {
    await folderService.remove(req.auth.sub, req.params.id);
    (req.log || logger).info({ userId: req.auth.sub, folderId: req.params.id }, "bookmark folder deleted");
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

module.exports = { list, create, update, remove };
