const favoriteDetailsService = require("../services/favorite-details.service");

async function list(req, res, next) {
  try {
    res.json({ favoriteDetails: await favoriteDetailsService.listFavoriteDetails(req.auth.sub, req.query.folderId) });
  } catch (error) {
    next(error);
  }
}

async function create(req, res, next) {
  try {
    const favoriteDetail = await favoriteDetailsService.createFavoriteDetail(req.auth.sub, req.body);
    res.status(201).json({ favoriteDetail });
  } catch (error) {
    next(error);
  }
}

module.exports = { list, create };
