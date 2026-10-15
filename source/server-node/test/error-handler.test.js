const test = require("node:test");
const assert = require("node:assert/strict");
const errorHandler = require("../src/middlewares/error-handler");

test("error handler logs the error and preserves the unauthorized response", () => {
  const error = new Error("token expired");
  error.name = "UnauthorizedError";
  const logged = [];
  const response = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    }
  };

  errorHandler(error, { id: "request-1", log: { error: (...args) => logged.push(args) } }, response);

  assert.equal(response.statusCode, 401);
  assert.deepEqual(response.body, { message: "登录已失效或缺少 Bearer token" });
  assert.equal(logged.length, 1);
  assert.equal(logged[0][0].err, error);
  assert.equal(logged[0][1], "request failed");
});
