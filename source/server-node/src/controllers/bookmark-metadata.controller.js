const metadataService = require("../services/bookmark-metadata.service");

async function fetchMetadata(req, res, next) {
  try {
    res.json({ metadata: await metadataService.fetchMetadata(req.body) });
  } catch (error) {
    next(error);
  }
}

module.exports = { fetchMetadata };
