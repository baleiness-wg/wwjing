const path = require("node:path");
const transferModel = require("../models/transfer.model");

const maxFileSize = 100 * 1024 * 1024;

async function getContent(req, res, next) {
  try {
    const content = await transferModel.findByUserId(req.auth.sub);
    if (!content) return res.json({ content: null });
    if (content.contentType === "text") {
      return res.json({ content: { type: "text", text: content.payload.toString("utf8"), updatedAt: content.updatedAt } });
    }
    return res.json({ content: {
      type: "file", fileName: content.fileName, mimeType: content.mimeType,
      fileSize: Number(content.fileSize), updatedAt: content.updatedAt
    } });
  } catch (error) {
    next(error);
  }
}

async function saveText(req, res, next) {
  try {
    if (typeof req.body.text !== "string" || !req.body.text.trim()) {
      return res.status(400).json({ message: "text is required" });
    }
    await transferModel.upsertText(req.auth.sub, req.body.text);
    res.json({ message: "content saved", type: "text" });
  } catch (error) {
    next(error);
  }
}

async function saveFile(req, res, next) {
  try {
    if (!req.file) return res.status(400).json({ message: "file is required" });
    if (req.file.size > maxFileSize) return res.status(413).json({ message: "file must be 100 MB or smaller" });
    const file = { ...req.file, originalname: path.basename(req.file.originalname) };
    await transferModel.upsertFile(req.auth.sub, file);
    res.json({ message: "content saved", type: "file", fileName: file.originalname, fileSize: file.size });
  } catch (error) {
    next(error);
  }
}

async function downloadFile(req, res, next) {
  try {
    const content = await transferModel.findByUserId(req.auth.sub);
    if (!content) return res.status(404).json({ message: "no content found" });
    if (content.contentType !== "file") return res.status(409).json({ message: "current content is not a file" });
    res.type(content.mimeType).attachment(content.fileName).send(content.payload);
  } catch (error) {
    next(error);
  }
}

module.exports = { getContent, saveText, saveFile, downloadFile, maxFileSize };
