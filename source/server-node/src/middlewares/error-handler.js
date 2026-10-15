function errorHandler(error, req, res, next) {
  const requestLogger = req.log || console;

  if (error.name === "UnauthorizedError") {
    requestLogger.warn({ err: error }, "request rejected: authentication required");
    return res.status(401).json({ message: "登录已失效或缺少 Bearer token" });
  }

  if (error.code === "LIMIT_FILE_SIZE") {
    requestLogger.warn({ err: error }, "request rejected: file is too large");
    return res.status(413).json({ message: "file must be 100 MB or smaller" });
  }

  if (error.status && error.status < 500) {
    requestLogger.warn({ err: error }, "request rejected");
  } else {
    requestLogger.error({ err: error }, "request failed unexpectedly");
  }

  res.status(error.status || 500).json({
    message: error.status ? error.message : "服务器内部错误"
  });
}

module.exports = errorHandler;
