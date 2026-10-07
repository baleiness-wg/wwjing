const foldersService = require("../services/folders.service");

async function list(req, res, next) {
  try {
    res.json({ folders: await foldersService.listFolders(req.auth.sub) });
  } catch (error) {
    next(error);
  }
}

async function create(req, res, next) {
  try {
    res.status(201).json({ folder: await foldersService.createFolder(req.auth.sub, req.body) });
  } catch (error) {
    next(error);
  }
}

module.exports = { list, create };
