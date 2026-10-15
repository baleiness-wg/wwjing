const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const sourceRoot = path.join(__dirname, "..", "src");

function readSource(file) {
  return fs.readFileSync(path.join(sourceRoot, file), "utf8");
}

test("request-facing source does not write directly to the console", () => {
  const files = [
    "app.js",
    "controllers/auth.controller.js",
    "controllers/transfer.controller.js",
    "services/auth.service.js",
    "middlewares/auth.js"
  ];

  for (const file of files) {
    assert.doesNotMatch(readSource(file), /console\.(log|error|warn|info|debug)/);
  }
});

test("logger redacts authentication and content fields", () => {
  const loggerSource = readSource("logger.js");

  for (const field of [
    "req.headers.authorization",
    "req.body.password",
    "req.body.token",
    "req.body.text",
    "req.body.file"
  ]) {
    assert.ok(loggerSource.includes(`"${field}"`));
  }
});
