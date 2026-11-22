const OSS = require("ali-oss");
const config = require("../config");
const crypto = require("node:crypto");
const BookmarkError = require("./bookmark-errors");

function client() {
  const { region, bucket, endpoint, accessKeyId, accessKeySecret } = config.oss;
  if (!region || !bucket || !endpoint || !accessKeyId || !accessKeySecret) {
    throw new BookmarkError(503, "OSS_NOT_CONFIGURED", "OSS 尚未配置，请联系管理员");
  }
  return new OSS({ region, bucket, endpoint, accessKeyId, accessKeySecret, secure: true });
}

async function upload(userId, itemId, file) {
  if (!file || !file.buffer) throw new BookmarkError(400, "INVALID_IMAGE", "请选择图片文件");
  if (!/^image\/(jpeg|png|webp|gif)$/i.test(file.mimetype)) {
    throw new BookmarkError(400, "INVALID_IMAGE", "仅支持 JPG、PNG、WEBP 或 GIF 图片");
  }
  if (file.size > 10 * 1024 * 1024) throw new BookmarkError(400, "INVALID_IMAGE", "图片不能超过 10 MB");
  const extension = file.mimetype.split("/")[1].replace("jpeg", "jpg");
  const key = `users/${userId}/bookmarks/${itemId}/${crypto.randomUUID()}.${extension}`;
  const result = await client().put(key, file.buffer, { headers: { "Content-Type": file.mimetype } });
  return { key, url: result.url };
}

module.exports = { upload };
