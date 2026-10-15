const test = require("node:test");
const assert = require("node:assert/strict");
const logger = require("../src/logger");

test("startup logger has service and environment bindings", () => {
  const bindings = logger.bindings();

  assert.equal(bindings.service, process.env.SERVICE_NAME || "wwjing-server");
  assert.equal(bindings.environment, process.env.NODE_ENV || "development");
});
