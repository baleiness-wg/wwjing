const test = require("node:test");
const assert = require("node:assert/strict");
const config = require("../src/config");
const aiService = require("../src/services/ai.service");

const originalAi = { ...config.ai };

function restoreConfig() {
  Object.assign(config.ai, originalAi);
}

test("AI service sends a bounded OpenAI-compatible request and returns the answer", async () => {
  Object.assign(config.ai, {
    apiKey: "test-key",
    baseUrl: "https://agnes.example/v1",
    model: "test-model",
    timeoutMs: 1000
  });
  let request;
  try {
    const result = await aiService.chat({
      context: {
        space: "star",
        directoryId: "1",
        directoryName: "技术",
        directoryPath: "技术",
        items: [{ title: "文章", description: "摘要", sourceHost: "example.com", sourceUrl: "https://example.com" }]
      },
      message: "请总结",
      history: [],
      fetchImpl: async (url, options) => {
        request = { url, options, body: JSON.parse(options.body) };
        return { ok: true, json: async () => ({ choices: [{ message: { content: "这是总结" } }] }) };
      }
    });
    assert.equal(result.answer, "这是总结");
    assert.equal(request.url, "https://agnes.example/v1/chat/completions");
    assert.equal(request.options.headers.Authorization, "Bearer test-key");
    assert.equal(request.body.model, "test-model");
    assert.equal(request.body.messages.at(-1).content, "请总结");
  } finally {
    restoreConfig();
  }
});

test("AI service rejects missing configuration and provider timeout", async () => {
  Object.assign(config.ai, { apiKey: "", baseUrl: "", model: "" });
  await assert.rejects(() => aiService.chat({ context: { space: "star", items: [] }, message: "问题", fetchImpl: async () => ({}) }), (error) => {
    assert.equal(error.code, "AI_NOT_CONFIGURED");
    return true;
  });

  Object.assign(config.ai, { apiKey: "key", baseUrl: "https://agnes.example/v1", model: "model", timeoutMs: 1 });
  try {
    await assert.rejects(() => aiService.chat({ context: { space: "star", items: [] }, message: "问题", fetchImpl: async () => {
      const error = new Error("aborted");
      error.name = "AbortError";
      throw error;
    } }), (error) => {
      assert.equal(error.code, "AI_TIMEOUT");
      return true;
    });
  } finally {
    restoreConfig();
  }
});

test("AI service rejects an invalid provider response", async () => {
  Object.assign(config.ai, { apiKey: "key", baseUrl: "https://agnes.example/v1", model: "model" });
  try {
    await assert.rejects(() => aiService.chat({
      context: { space: "star", items: [] },
      message: "问题",
      fetchImpl: async () => ({ ok: true, json: async () => ({ choices: [] }) })
    }), (error) => {
      assert.equal(error.code, "AI_INVALID_RESPONSE");
      assert.equal(error.providerReason, "missing_chat_content");
      return true;
    });
  } finally {
    restoreConfig();
  }
});

test("AI service distinguishes invalid JSON from network failures", async () => {
  Object.assign(config.ai, { apiKey: "key", baseUrl: "https://agnes.example/v1", model: "model" });
  try {
    await assert.rejects(() => aiService.chat({
      context: { space: "star", items: [] },
      message: "问题",
      fetchImpl: async () => ({ ok: true, status: 200, json: async () => { throw new Error("invalid json"); } })
    }), (error) => {
      assert.equal(error.code, "AI_INVALID_RESPONSE");
      assert.equal(error.providerReason, "invalid_json");
      return true;
    });

    await assert.rejects(() => aiService.chat({
      context: { space: "star", items: [] },
      message: "问题",
      fetchImpl: async () => { throw new Error("network unavailable"); }
    }), (error) => {
      assert.equal(error.code, "AI_PROVIDER_ERROR");
      assert.equal(error.providerReason, "Error");
      return true;
    });
  } finally {
    restoreConfig();
  }
});

test("AI service maps provider authentication, model, and rate-limit failures", async () => {
  Object.assign(config.ai, { apiKey: "key", baseUrl: "https://agnes.example/v1", model: "model" });
  try {
    for (const [status, code] of [[401, "AI_AUTH_FAILED"], [404, "AI_MODEL_NOT_FOUND"], [429, "AI_RATE_LIMITED"]]) {
      await assert.rejects(() => aiService.chat({
        context: { space: "star", items: [] },
        message: "问题",
        fetchImpl: async () => ({ ok: false, status })
      }), (error) => {
        assert.equal(error.code, code);
        assert.equal(error.providerStatus, status);
        return true;
      });
    }
  } finally {
    restoreConfig();
  }
});

test("AI service retries transient provider failures and does not retry auth failures", async () => {
  Object.assign(config.ai, { apiKey: "key", baseUrl: "https://agnes.example/v1", model: "model" });
  try {
    let attempts = 0;
    const result = await aiService.chat({
      context: { space: "star", items: [] },
      message: "问题",
      fetchImpl: async () => {
        attempts += 1;
        if (attempts < 3) return { ok: false, status: 503 };
        return { ok: true, json: async () => ({ choices: [{ message: { content: "成功" } }] }) };
      }
    });
    assert.equal(result.answer, "成功");
    assert.equal(attempts, 3);

    attempts = 0;
    await assert.rejects(() => aiService.chat({
      context: { space: "star", items: [] },
      message: "问题",
      fetchImpl: async () => {
        attempts += 1;
        return { ok: false, status: 401 };
      }
    }), (error) => {
      assert.equal(error.code, "AI_AUTH_FAILED");
      return true;
    });
    assert.equal(attempts, 1);
  } finally {
    restoreConfig();
  }
});

test("AI context uses an allowlist and truncates oversized items", () => {
  const result = aiService.sanitizeContext({
    space: "star",
    directoryId: "1",
    apiKey: "do-not-send",
    items: Array.from({ length: 200 }, (_, index) => ({
      title: `item-${index}`,
      description: "x".repeat(1000),
      sourceUrl: "https://example.com",
      password: "secret",
      body: "binary"
    }))
  });
  assert.ok(result.context.items.length <= aiService.MAX_CONTEXT_ITEMS);
  assert.equal(result.context.apiKey, undefined);
  assert.equal(result.context.items[0].password, undefined);
  assert.ok(result.serialized.length <= aiService.MAX_CONTEXT_LENGTH);
  assert.equal(result.truncated, true);
});

test("AI request metadata does not include prompt, reply, or credentials", async () => {
  Object.assign(config.ai, { apiKey: "secret-key", baseUrl: "https://agnes.example/v1", model: "model" });
  const result = aiService.buildMessages({
    context: { space: "star", items: [{ title: "private title", description: "private description" }] },
    message: "private question",
    history: []
  });
  const metadata = JSON.stringify({
    space: result.context.space,
    itemCount: result.context.items.length,
    messageLength: "private question".length,
    durationMs: 1
  });
  assert.equal(metadata.includes("private question"), false);
  assert.equal(metadata.includes("secret-key"), false);
  assert.equal(metadata.includes("private description"), false);
  restoreConfig();
});

test("AI reply appends the original link when it mentions a known item", () => {
  assert.equal(
    aiService.appendMentionedItemLinks("建议先看 Flutter 入门", {
      items: [{ title: "Flutter 入门", sourceUrl: "https://example.com/flutter" }]
    }),
    "建议先看 Flutter 入门（https://example.com/flutter）"
  );
  assert.equal(
    aiService.appendMentionedItemLinks("这是泛泛讨论", { items: [{ title: "Flutter 入门", sourceUrl: "https://example.com/flutter" }] }),
    "这是泛泛讨论"
  );
});
