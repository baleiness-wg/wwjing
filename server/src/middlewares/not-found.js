function notFound(req, res) {
  res.status(404).json({ message: "接口不存在" });
}

module.exports = notFound;
