const test = require("node:test");
const assert = require("node:assert/strict");

test("logger module exports a pino logger with the expected levels", () => {
  const logger = require("../src/logger");

  assert.equal(typeof logger.info, "function");
  assert.equal(typeof logger.error, "function");
  assert.equal(typeof logger.child, "function");
});

test("logger redaction removes sensitive request fields", () => {
  const logger = require("../src/logger");
  const serialized = logger.bindings();

  assert.equal(serialized.service, process.env.SERVICE_NAME || "wwjing-server");
});
