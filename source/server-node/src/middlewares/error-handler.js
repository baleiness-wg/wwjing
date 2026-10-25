function errorHandler(error, req, res, next) {
  const requestLogger = req.log || require("../logger");
  requestLogger.error({ err: error }, "request failed");

  if (error.name === "UnauthorizedError") {
    return res.status(401).json({ message: "登录已失效或缺少 Bearer token" });
  }

  if (error.code === "LIMIT_FILE_SIZE") {
    return res.status(413).json({ message: "file must be 100 MB or smaller" });
  }

  if (error.name === "BookmarkError") {
    return res.status(error.status).json({
      error: {
        code: error.code,
        message: error.message,
        ...(error.details || {})
      }
    });
  }

  res.status(error.status || 500).json({
    message: error.status ? error.message : "服务器内部错误"
  });
}

module.exports = errorHandler;
