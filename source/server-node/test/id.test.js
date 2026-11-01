const test = require("node:test");
const assert = require("node:assert/strict");
const { randomId } = require("../src/utils/id");

test("randomId returns a unique lowercase MD5-shaped identifier", () => {
  const first = randomId();
  const second = randomId();
  assert.match(first, /^[a-f0-9]{32}$/);
  assert.match(second, /^[a-f0-9]{32}$/);
  assert.notEqual(first, second);
});
