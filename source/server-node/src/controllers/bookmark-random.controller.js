const randomService = require("../services/bookmark-random.service");

async function random(req, res, next) {
  try {
    res.json({ item: await randomService.random(req.auth.sub, req.query) });
  } catch (error) {
    next(error);
  }
}

module.exports = { random };
