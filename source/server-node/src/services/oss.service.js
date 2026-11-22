const OSS = require("ali-oss");
const config = require("../config");
const crypto = require("node:crypto");
const BookmarkError = require("./bookmark-errors");
const path = require("node:path");

function client() {
  const { region, bucket, endpoint, accessKeyId, accessKeySecret } = config.oss;
  const missing = [
    ["OSS_REGION", region],
    ["OSS_BUCKET", bucket],
    ["OSS_ENDPOINT", endpoint],
    ["OSS_ACCESS_KEY_ID", accessKeyId],
    ["OSS_ACCESS_KEY_SECRET", accessKeySecret]
  ].filter(([, value]) => !value).map(([name]) => name);
  if (missing.length) {
    throw new BookmarkError(503, "OSS_NOT_CONFIGURED", `OSS 尚未配置：缺少 ${missing.join(", ")}`);
  }
  return new OSS({ region, bucket, endpoint, accessKeyId, accessKeySecret, secure: true });
}

async function upload(userId, itemId, file) {
  if (!file || !file.buffer) throw new BookmarkError(400, "INVALID_IMAGE", "请选择图片文件");
  const extension = path.extname(file.originalname || "").toLowerCase().replace(".", "");
  const allowedExtensions = new Set(["jpg", "jpeg", "png", "webp", "gif", "heic", "heif"]);
  const allowedMime = /^image\/(jpeg|jpg|png|webp|gif|heic|heif)$/i.test(file.mimetype || "");
  const allowedByName = allowedExtensions.has(extension);
  if (!allowedMime && !allowedByName) {
    throw new BookmarkError(400, "INVALID_IMAGE", "仅支持 JPG、PNG、WEBP 或 GIF 图片");
  }
  if (file.size > 10 * 1024 * 1024) throw new BookmarkError(400, "INVALID_IMAGE", "图片不能超过 10 MB");
  const normalizedExtension = extension === "jpeg" ? "jpg" : extension || "jpg";
  const contentType = allowedMime ? file.mimetype : `image/${normalizedExtension}`;
  const key = `users/${userId}/bookmarks/${itemId}/${crypto.randomUUID()}.${normalizedExtension}`;
  const ossClient = client();
  await ossClient.put(key, file.buffer, { headers: { "Content-Type": contentType } });
  const url = ossClient.signatureUrl(key, {
    expires: config.oss.signedUrlExpires,
    response: { "content-disposition": "inline" }
  });
  return { key, url, expiresIn: config.oss.signedUrlExpires };
}

module.exports = { upload };
