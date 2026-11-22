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
    if (typeof req.body?.pinned !== "boolean") {
      return res.status(400).json({ error: { code: "INVALID_INPUT", message: "pinned 必须是布尔值" } });
    }
    await itemService.pin(req.auth.sub, req.params.id, req.body.folderId, req.body.pinned, req.body?.space || "star");
    res.status(204).send();
  } catch (error) { next(error); }
}

const uploadImages = [upload.single("image"), async (req, res, next) => {
  try {
    (req.log || logger).info({ userId: req.auth.sub, itemId: req.params.id, hasFile: Boolean(req.file), fileSize: req.file?.size, mime: req.file?.mimetype }, "bookmark image upload started");
    const item = await itemService.get(req.auth.sub, req.params.id, req.body?.space || "star");
    const uploaded = await oss.upload(req.auth.sub, item.id, req.file);
    (req.log || logger).info({ userId: req.auth.sub, itemId: item.id, objectKey: uploaded.key }, "bookmark image uploaded to oss");
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
    if (!updated) throw new Error("图片上传后收藏更新失败：找不到收藏条目");
    (req.log || logger).info({ userId: req.auth.sub, itemId: item.id, imageCount: updated.images?.length || 0 }, "bookmark images saved");
    res.status(201).json({ image: uploaded.url, images: updated.images || [uploaded.url] });
  } catch (error) {
    (req.log || logger).error({ userId: req.auth?.sub, itemId: req.params.id, code: error.code, message: error.message }, "bookmark image upload failed");
    next(error);
  }
}];

module.exports = { list, create, get, update, remove, pin, uploadImages };
