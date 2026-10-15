const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const app = require("../src/app");
const { sanitizeLogFields } = require("../src/log-sanitizer");

test("sanitizes credentials, tokens, and binary payloads", () => {
  const sanitized = sanitizeLogFields({
    password: "password-value",
    authorization: "Bearer token-value",
    jwt: "jwt-value",
    databasePassword: "database-value",
    payload: Buffer.from("file-content"),
    fileSize: 12
  });

  assert.equal(sanitized.password, "[REDACTED]");
  assert.equal(sanitized.authorization, "[REDACTED]");
  assert.equal(sanitized.jwt, "[REDACTED]");
  assert.equal(sanitized.databasePassword, "[REDACTED]");
  assert.equal(sanitized.payload, "[Buffer 12 bytes]");
  assert.equal(sanitized.fileSize, 12);
  assert.equal(JSON.stringify(sanitized).includes("token-value"), false);
  assert.equal(JSON.stringify(sanitized).includes("file-content"), false);
});

test("production logger writes parseable structured output", () => {
  const result = spawnSync(process.execPath, [
    "-e",
    "const logger=require('./src/logger'); logger.info({sample:'value'}, 'test message')"
  ], {
    cwd: require("node:path").join(__dirname, ".."),
    encoding: "utf8",
    env: { ...process.env, NODE_ENV: "production", LOG_LEVEL: "info" }
  });

  assert.equal(result.status, 0, result.stderr);
  const record = JSON.parse(result.stdout.trim());
  assert.equal(record.service, "wwjing-server");
  assert.equal(record.environment, "production");
  assert.equal(record.msg, "test message");
  assert.equal(record.sample, "value");
});

test("health response includes an HTTP request correlation id", async () => {
  const server = app.listen(0, "127.0.0.1");

  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/health`);
    assert.equal(response.status, 200);
    assert.match(response.headers.get("x-request-id"), /^[0-9a-f-]{36}$/);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
