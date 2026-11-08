const config = require("../config");

const MAX_MESSAGE_LENGTH = 4000;
const MAX_HISTORY_MESSAGES = 20;
const MAX_CONTEXT_ITEMS = 100;
const MAX_FIELD_LENGTH = 500;
const MAX_CONTEXT_LENGTH = 24000;

class AiError extends Error {
  constructor(code, message, status = 503, providerStatus) {
    super(message);
    this.name = "AiError";
    this.code = code;
    this.status = status;
    this.providerStatus = providerStatus;
  }
}

function limitedString(value, maxLength = MAX_FIELD_LENGTH) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function sanitizeContext(input = {}) {
  const rawItems = Array.isArray(input.items) ? input.items : [];
  const items = rawItems.slice(0, MAX_CONTEXT_ITEMS).map((item) => ({
    title: limitedString(item?.title),
    description: limitedString(item?.description),
    sourceHost: limitedString(item?.sourceHost, 120),
    sourceUrl: limitedString(item?.sourceUrl, 1000),
    folderPath: limitedString(item?.folderPath, 300)
  }));

  const context = {
    space: limitedString(input.space, 32),
    directoryId: input.directoryId === null || input.directoryId === undefined ? null : String(input.directoryId).slice(0, 100),
    directoryName: limitedString(input.directoryName, 200),
    directoryPath: limitedString(input.directoryPath, 500),
    loadedItemCount: Number.isFinite(Number(input.loadedItemCount)) ? Number(input.loadedItemCount) : items.length,
    items
  };

  let serialized = JSON.stringify(context);
  if (serialized.length > MAX_CONTEXT_LENGTH) {
    while (context.items.length && JSON.stringify(context).length > MAX_CONTEXT_LENGTH) context.items.pop();
    serialized = JSON.stringify(context);
  }

  return {
    context,
    serialized,
    truncated: rawItems.length > items.length || rawItems.length !== context.items.length
  };
}

function normalizeHistory(history = []) {
  return history.slice(-MAX_HISTORY_MESSAGES).map((entry) => ({
    role: entry.role === "assistant" ? "assistant" : "user",
    content: limitedString(entry.content, MAX_MESSAGE_LENGTH)
  })).filter((entry) => entry.content);
}

function buildMessages({ context, message, history }) {
  const contextResult = sanitizeContext(context);
  const limitation = contextResult.truncated
    ? "当前上下文已因容量限制截断，只代表当前已加载的部分收藏。"
    : "当前上下文只代表当前页面已加载的收藏，不包含网页全文。";
  const system = [
    "你是鲸界收藏夹的中文目录助手。请基于给定目录上下文回答问题。",
    "不要臆造上下文中不存在的事实；无法判断时明确说明。",
    limitation,
    `目录上下文：${contextResult.serialized}`
  ].join("\n");

  return {
    messages: [
      { role: "system", content: system },
      ...normalizeHistory(history),
      { role: "user", content: limitedString(message, MAX_MESSAGE_LENGTH) }
    ],
    context: contextResult.context,
    truncated: contextResult.truncated
  };
}

function endpointFor(baseUrl) {
  const normalized = baseUrl.replace(/\/$/, "");
  return normalized.endsWith("/chat/completions") ? normalized : `${normalized}/chat/completions`;
}

async function requestProvider(messages, fetchImpl = globalThis.fetch) {
  if (!config.ai.apiKey || !config.ai.baseUrl || !config.ai.model) {
    throw new AiError("AI_NOT_CONFIGURED", "AI 服务尚未完成配置", 503);
  }

  if (typeof fetchImpl !== "function") {
    throw new AiError("AI_PROVIDER_ERROR", "当前 Node 环境不支持 AI 请求", 503);
  }

  const abortController = new AbortController();
  const timeout = setTimeout(() => abortController.abort(), config.ai.timeoutMs);
  try {
    const response = await fetchImpl(endpointFor(config.ai.baseUrl), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${config.ai.apiKey}`
      },
      body: JSON.stringify({
        model: config.ai.model,
        messages,
        temperature: 0.3
      }),
      signal: abortController.signal
    });

    if (!response.ok) {
      const providerStatus = response.status;
      let providerCode = "AI_PROVIDER_ERROR";
      let message = "AI 服务暂时不可用";
      if (providerStatus === 401 || providerStatus === 403) {
        providerCode = "AI_AUTH_FAILED";
        message = "AI API Key 无效或无权访问该模型";
      } else if (providerStatus === 404) {
        providerCode = "AI_MODEL_NOT_FOUND";
        message = "AI 接口地址或模型不存在";
      } else if (providerStatus === 429) {
        providerCode = "AI_RATE_LIMITED";
        message = "AI 服务请求过于频繁或额度不足";
      }
      throw new AiError(providerCode, message, providerStatus === 429 ? 429 : 502, providerStatus);
    }
    const payload = typeof response.json === "function"
      ? await response.json()
      : JSON.parse(await response.text());
    const answer = payload?.choices?.[0]?.message?.content;
    if (typeof answer !== "string" || !answer.trim()) throw new AiError("AI_PROVIDER_ERROR", "AI 服务返回了无效响应", 502);
    return answer.trim();
  } catch (error) {
    if (error instanceof AiError) throw error;
    if (error.name === "AbortError") throw new AiError("AI_TIMEOUT", "AI 服务响应超时", 504);
    throw new AiError("AI_PROVIDER_ERROR", "AI 服务暂时不可用", 502);
  } finally {
    clearTimeout(timeout);
  }
}

async function chat({ context, message, history = [], fetchImpl }) {
  const prepared = buildMessages({ context, message, history });
  const answer = await requestProvider(prepared.messages, fetchImpl);
  return {
    answer,
    context: prepared.context,
    truncated: prepared.truncated
  };
}

module.exports = {
  AiError,
  MAX_CONTEXT_ITEMS,
  MAX_CONTEXT_LENGTH,
  MAX_HISTORY_MESSAGES,
  MAX_MESSAGE_LENGTH,
  buildMessages,
  chat,
  sanitizeContext
};
