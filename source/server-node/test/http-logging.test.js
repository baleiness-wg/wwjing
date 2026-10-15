const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const app = require("../src/app");

test("health request returns a request id and preserves the health response", async () => {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const { port } = server.address();

  try {
    const response = await fetch(`http://127.0.0.1:${port}/api/health`, {
      headers: { "x-request-id": "test-request-id" }
    });

    assert.equal(response.status, 200);
    assert.equal(response.headers.get("x-request-id"), "test-request-id");
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
});
