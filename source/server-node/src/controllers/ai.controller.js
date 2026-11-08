const aiService = require("../services/ai.service");
const logger = require("../logger");

const validSpaces = new Set(["cookie", "star"]);

function validateInput(body = {}) {
  if (!body || typeof body !== "object") return "请求内容无效";
  if (!validSpaces.has(body.context?.space)) return "收藏空间无效";
  if (!body.context || typeof body.context !== "object") return "目录上下文无效";
  if (typeof body.message !== "string" || !body.message.trim() || body.message.length > aiService.MAX_MESSAGE_LENGTH) {
    return "问题不能为空且不能超过 4000 个字符";
  }
  if (!Array.isArray(body.history) || body.history.length > aiService.MAX_HISTORY_MESSAGES) {
    return "对话历史数量无效";
  }
  if (body.history.some((entry) => !entry || !["user", "assistant"].includes(entry.role) || typeof entry.content !== "string" || !entry.content.trim() || entry.content.length > aiService.MAX_MESSAGE_LENGTH)) {
    return "对话历史内容无效";
  }
  if (!Array.isArray(body.context.items)) return "目录收藏上下文无效";
  return null;
}

async function chat(req, res, next) {
  const invalidMessage = validateInput(req.body);
  if (invalidMessage) {
    return res.status(400).json({ error: { code: "AI_INVALID_INPUT", message: invalidMessage } });
  }

  const startedAt = Date.now();
  const requestLogger = req.log || logger;
  try {
    const result = await aiService.chat({
      context: req.body.context,
      message: req.body.message,
      history: req.body.history
    });
    requestLogger.info({
      userId: req.auth.sub,
      space: result.context.space,
      directoryId: result.context.directoryId,
      itemCount: result.context.items.length,
      messageLength: req.body.message.length,
      durationMs: Date.now() - startedAt,
      truncated: result.truncated
    }, "ai chat completed");
    return res.json({ answer: result.answer, truncated: result.truncated });
  } catch (error) {
    requestLogger.warn({
      userId: req.auth.sub,
      space: req.body.context.space,
      directoryId: req.body.context.directoryId,
      messageLength: req.body.message.length,
      durationMs: Date.now() - startedAt,
      errorCode: error.code || "AI_PROVIDER_ERROR",
      providerStatus: error.providerStatus
    }, "ai chat failed");
    return next(error);
  }
}

module.exports = { chat, validateInput };
