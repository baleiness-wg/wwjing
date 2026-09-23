function errorHandler(error, req, res, next) {
  console.error(error);

  if (error.name === "UnauthorizedError") {
    return res.status(401).json({ message: "登录已失效或缺少 Bearer token" });
  }

  res.status(error.status || 500).json({
    message: error.status ? error.message : "服务器内部错误"
  });
}

module.exports = errorHandler;
