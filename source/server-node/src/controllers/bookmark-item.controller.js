const itemService = require("../services/bookmark-item.service");
const logger = require("../logger");
const multer = require("multer");
const oss = require("../services/oss.service");
const itemModel = require("../models/bookmark-item.model");
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

async function list(req, res, next) {
  try {
    res.json(await itemService.list(req.auth.sub, { ...req.query, space: req.query.space || "star" }));
  } catch (error) {
    next(error);
  }
}

async function create(req, res, next) {
  try {
    const item = await itemService.create(req.auth.sub, { ...req.body, space: req.body.space || "star" });
    (req.log || logger).info({ userId: req.auth.sub, itemId: item.id }, "bookmark item created");
    res.status(201).json({ item });
  } catch (error) {
    next(error);
  }
}

async function get(req, res, next) {
  try {
    res.json({ item: await itemService.get(req.auth.sub, req.params.id, req.query.space || "star") });
  } catch (error) {
    next(error);
  }
}

async function update(req, res, next) {
  try {
    const item = await itemService.update(req.auth.sub, req.params.id, { ...req.body, space: req.body.space || "star" });
    (req.log || logger).info({ userId: req.auth.sub, itemId: item.id }, "bookmark item updated");
    res.json({ item });
  } catch (error) {
    next(error);
  }
}

async function remove(req, res, next) {
  try {
    await itemService.remove(req.auth.sub, req.params.id, req.query.space || req.body?.space || "star");
    (req.log || logger).info({ userId: req.auth.sub, itemId: req.params.id }, "bookmark item deleted");
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

async function pin(req, res, next) {
  try {
    await itemService.pin(req.auth.sub, req.params.id, req.body?.folderId, req.body?.pinned === true, req.body?.space || "star");
    res.status(204).send();
  } catch (error) { next(error); }
}

const uploadImages = [upload.single("image"), async (req, res, next) => {
  try {
    const item = await itemService.get(req.auth.sub, req.params.id, req.body?.space || "star");
    const uploaded = await oss.upload(req.auth.sub, item.id, req.file);
    const images = [
      ...(item.images || []).map(oss.objectKey),
      uploaded.key
    ];
    const updated = await itemModel.update(req.auth.sub, item.id, {
      space: req.body?.space || "star",
      folderId: item.folderId,
      folderIds: item.folderIds || [],
      title: item.title,
      description: item.description,
      images,
      sourceUrl: item.sourceUrl,
      normalizedUrl: item.normalizedUrl,
      sourceHost: item.sourceHost,
      metadata: item.metadata || {}
    });
    res.status(201).json({ image: uploaded.url, images: updated.images || [uploaded.url] });
  } catch (error) { next(error); }
}];

module.exports = { list, create, get, update, remove, pin, uploadImages };
