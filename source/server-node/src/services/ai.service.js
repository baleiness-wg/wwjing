const config = require("../config");
const dns = require("node:dns");
const https = require("node:https");

const MAX_MESSAGE_LENGTH = 4000;
const MAX_HISTORY_MESSAGES = 20;
const MAX_CONTEXT_ITEMS = 100;
const MAX_FIELD_LENGTH = 500;
const MAX_CONTEXT_LENGTH = 24000;
const AI_MAX_ATTEMPTS = 5;
const AI_RETRY_DELAYS_MS = [300, 900, 1800, 3000];

class AiError extends Error {
  constructor(code, message, status = 503, providerStatus, providerReason) {
    super(message);
    this.name = "AiError";
    this.code = code;
    this.status = status;
    this.providerStatus = providerStatus;
    this.providerReason = providerReason;
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
  const recommendationRequest = /推荐|建议|今天.*(做什么|干嘛|安排)|干嘛|做什么|选几个|挑几个|先看|值得看|适合/.test(message);
  const limitation = contextResult.truncated
    ? "当前上下文已因容量限制截断，只代表当前已加载的部分收藏。"
    : "当前上下文只代表当前页面已加载的收藏，不包含网页全文。";
  const system = [
    "你是一个自然、友好的收藏夹 AI 助手。请围绕当前目录收藏理解和回答用户的问题；当前目录内容是主要参考，而不是可有可无的背景。",
    "当用户询问推荐、建议、今天做什么、先看什么、值得看什么或类似问题时，应优先从当前收藏中寻找合适内容，而不是给脱离收藏的泛泛建议。",
    recommendationRequest
      ? "这是一个基于收藏夹的建议请求。请自然地参考当前收藏回答，不限制数量，不使用固定模板；如果提到具体收藏，就在对应名称后自然附上该收藏的原始链接。"
      : "如果用户询问当前目录内容，可以自然参考收藏；如果提到具体收藏，可以在对应名称后附上原始链接。",
    "链接必须原样使用目录上下文中的 sourceUrl，不要改写或编造链接。",
    "如果目录上下文不足以回答问题，请直接说明不确定，不要编造事实，也不要把所有收藏重复罗列出来。",
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

function appendMentionedItemLinks(answer, context) {
  let enriched = answer.replace(/https?:\/\/[^\s<（(]*[（(](https?:\/\/[^\s）)>]+)[）)>][^\s]*/gi, "$1");
  for (const item of context.items) {
    const title = limitedString(item.title, MAX_FIELD_LENGTH);
    const url = limitedString(item.sourceUrl, 1000);
    if (title.length < 2 || !url || !enriched.includes(title) || enriched.includes(url)) continue;
    enriched = enriched.replace(title, `${title}（${url}）`);
  }
  return enriched;
}

function endpointFor(baseUrl) {
  const normalized = baseUrl.replace(/\/$/, "");
  return normalized.endsWith("/chat/completions") ? normalized : `${normalized}/chat/completions`;
}

function isRetryableAiError(error) {
  return error.code === "AI_TIMEOUT"
    || error.code === "AI_PROVIDER_ERROR" && !error.providerStatus
    || error.providerStatus === 408
    || error.providerStatus === 429
    || error.providerStatus >= 500;
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function fetchProviderOverIpv4(url, options) {
  const target = new URL(url);
  const addresses = await new Promise((resolve, reject) => {
    dns.resolve4(target.hostname, (error, values) => error ? reject(error) : resolve(values));
  });
  if (!addresses.length) throw new Error("No IPv4 address resolved");
  return new Promise((resolve, reject) => {
    const request = https.request({
      hostname: addresses[0],
      port: 443,
      path: `${target.pathname}${target.search}`,
      method: options.method,
      headers: { ...options.headers, Host: target.hostname },
      servername: target.hostname,
      family: 4
    }, (response) => {
      const chunks = [];
      response.on("data", (chunk) => chunks.push(chunk));
      response.on("end", () => {
        const body = Buffer.concat(chunks).toString("utf8");
        resolve({
          ok: response.statusCode >= 200 && response.statusCode < 300,
          status: response.statusCode,
          async json() { return JSON.parse(body); },
          async text() { return body; }
        });
      });
    });
    request.on("error", reject);
    if (options.signal) {
      if (options.signal.aborted) request.destroy(new Error("request aborted"));
      options.signal.addEventListener("abort", () => request.destroy(new Error("request aborted")), { once: true });
    }
    request.write(options.body);
    request.end();
  });
}

async function requestProviderOnce(messages, fetchImpl) {
  if (!config.ai.apiKey || !config.ai.baseUrl || !config.ai.model) {
    throw new AiError("AI_NOT_CONFIGURED", "AI 服务尚未完成配置", 503);
  }

  const request = fetchImpl || fetchProviderOverIpv4;
  if (typeof request !== "function") {
    throw new AiError("AI_PROVIDER_ERROR", "当前 Node 环境不支持 AI 请求", 503);
  }

  const abortController = new AbortController();
  const timeout = setTimeout(() => abortController.abort(), config.ai.timeoutMs);
  try {
    const response = await request(endpointFor(config.ai.baseUrl), {
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
    let payload;
    try {
      payload = typeof response.json === "function"
        ? await response.json()
        : JSON.parse(await response.text());
    } catch (error) {
      throw new AiError("AI_INVALID_RESPONSE", "AI 服务返回了无法解析的响应", 502, response.status, "invalid_json");
    }
    const answer = payload?.choices?.[0]?.message?.content;
    if (typeof answer !== "string" || !answer.trim()) {
      throw new AiError("AI_INVALID_RESPONSE", "AI 服务返回格式不兼容", 502, response.status, "missing_chat_content");
    }
    return answer.trim();
  } catch (error) {
    if (error instanceof AiError) throw error;
    if (error.name === "AbortError") throw new AiError("AI_TIMEOUT", "AI 服务响应超时", 504);
    throw new AiError("AI_PROVIDER_ERROR", "AI 服务暂时不可用", 502, undefined, error.cause?.code || error.code || error.name || "request_failed");
  } finally {
    clearTimeout(timeout);
  }
}

async function requestProvider(messages, fetchImpl) {
  let lastError;
  for (let attempt = 0; attempt < AI_MAX_ATTEMPTS; attempt += 1) {
    try {
      return await requestProviderOnce(messages, fetchImpl);
    } catch (error) {
      lastError = error;
      error.attempts = attempt + 1;
      if (!isRetryableAiError(error) || attempt === AI_MAX_ATTEMPTS - 1) throw error;
      await wait(AI_RETRY_DELAYS_MS[attempt]);
    }
  }
  throw lastError;
}

async function chat({ context, message, history = [], fetchImpl }) {
  const prepared = buildMessages({ context, message, history });
  const answer = await requestProvider(prepared.messages, fetchImpl);
  return {
    answer: appendMentionedItemLinks(answer, prepared.context),
    context: prepared.context,
    truncated: prepared.truncated
  };
}

module.exports = {
  AiError,
  MAX_CONTEXT_ITEMS,
  MAX_CONTEXT_LENGTH,
  AI_MAX_ATTEMPTS,
  AI_RETRY_DELAYS_MS,
  MAX_HISTORY_MESSAGES,
  MAX_MESSAGE_LENGTH,
  buildMessages,
  appendMentionedItemLinks,
  chat,
  sanitizeContext
};
