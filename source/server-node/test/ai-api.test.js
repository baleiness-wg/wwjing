const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const jwt = require("jsonwebtoken");
const app = require("../src/app");
const config = require("../src/config");
const aiService = require("../src/services/ai.service");

async function withServer(callback) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    await callback(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

function token() {
  return jwt.sign({ sub: "42" }, config.jwtSecretKey, { algorithm: "HS256" });
}

const body = {
  context: { space: "star", directoryId: "1", directoryName: "技术", directoryPath: "技术", items: [] },
  message: "请总结当前目录",
  history: []
};

test("AI route rejects unauthenticated and invalid requests", async () => {
  await withServer(async (baseUrl) => {
    const unauthenticated = await fetch(`${baseUrl}/api/ai/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    assert.equal(unauthenticated.status, 401);

    const invalid = await fetch(`${baseUrl}/api/ai/chat`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" },
      body: JSON.stringify({ ...body, message: "" })
    });
    assert.equal(invalid.status, 400);
    assert.equal((await invalid.json()).error.code, "AI_INVALID_INPUT");
  });
});

test("AI route uses authenticated subject and returns provider answer", async () => {
  const originalChat = aiService.chat;
  let received;
  aiService.chat = async (input) => {
    received = input;
    return { answer: "目录分析结果", truncated: false, context: input.context };
  };
  try {
    await withServer(async (baseUrl) => {
      const response = await fetch(`${baseUrl}/api/ai/chat`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" },
        body: JSON.stringify({ ...body, userId: "999" })
      });
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), { answer: "目录分析结果", truncated: false });
      assert.equal(received.message, body.message);
      assert.equal(received.context.space, "star");
    });
  } finally {
    aiService.chat = originalChat;
  }
});

test("mock Agnes integration keeps space and directory context across conversations", async () => {
  const originalChat = aiService.chat;
  const received = [];
  aiService.chat = async (input) => {
    received.push(input);
    return {
      answer: `${input.context.space}/${input.context.directoryId}: ${input.message}`,
      truncated: false,
      context: input.context
    };
  };
  try {
    await withServer(async (baseUrl) => {
      const headers = { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" };
      for (const context of [
        { space: "star", directoryId: "star-1", directoryName: "技术", directoryPath: "技术", items: [] },
        { space: "cookie", directoryId: "cookie-2", directoryName: "晚餐", directoryPath: "菜谱 / 晚餐", items: [] }
      ]) {
        const first = await fetch(`${baseUrl}/api/ai/chat`, {
          method: "POST",
          headers,
          body: JSON.stringify({ context, history: [], message: "先介绍这个目录" })
        });
        assert.equal(first.status, 200);
        const firstAnswer = await first.json();
        assert.match(firstAnswer.answer, new RegExp(context.space));

        const followUp = await fetch(`${baseUrl}/api/ai/chat`, {
          method: "POST",
          headers,
          body: JSON.stringify({
            context,
            history: [{ role: "user", content: "先介绍这个目录" }, { role: "assistant", content: firstAnswer.answer }],
            message: "继续给一个建议"
          })
        });
        assert.equal(followUp.status, 200);
      }
    });
    assert.equal(received.length, 4);
    assert.equal(received[1].history.length, 2);
    assert.equal(received[0].context.space, "star");
    assert.equal(received[2].context.space, "cookie");
  } finally {
    aiService.chat = originalChat;
  }
});
