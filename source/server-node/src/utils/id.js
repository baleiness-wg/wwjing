const crypto = require("node:crypto");

function randomId() {
  return crypto.createHash("md5").update(crypto.randomBytes(32)).digest("hex");
}

module.exports = { randomId };
