const test = require("node:test");
const assert = require("node:assert/strict");
const transferController = require("../src/controllers/transfer.controller");
const transferModel = require("../src/models/transfer.model");

function responseDouble() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
    type() {
      return this;
    },
    attachment() {
      return this;
    },
    send(body) {
      this.body = body;
      return this;
    }
  };
}

test("saveText rejects blank input without touching the database", async () => {
  const response = responseDouble();
  let called = false;
  const original = transferModel.upsertText;
  transferModel.upsertText = async () => { called = true; };

  try {
    await transferController.saveText({ auth: { sub: "1" }, body: { text: "  " } }, response, assert.fail);
  } finally {
    transferModel.upsertText = original;
  }

  assert.equal(response.statusCode, 400);
  assert.equal(called, false);
});

test("getContent returns text from the authenticated user only", async () => {
  const response = responseDouble();
  const original = transferModel.findByUserId;
  let requestedUser;
  transferModel.findByUserId = async (userId) => {
    requestedUser = userId;
    return { contentType: "text", payload: Buffer.from("hello"), updatedAt: "now" };
  };

  try {
    await transferController.getContent({ auth: { sub: "42" } }, response, assert.fail);
  } finally {
    transferModel.findByUserId = original;
  }

  assert.equal(requestedUser, "42");
  assert.deepEqual(response.body.content, { type: "text", text: "hello", updatedAt: "now" });
});

test("saveFile rejects a missing file", async () => {
  const response = responseDouble();
  await transferController.saveFile({ auth: { sub: "1" } }, response, assert.fail);
  assert.equal(response.statusCode, 400);
  assert.equal(response.body.message, "file is required");
});
