function getHealth(req, res) {
  res.json({ status: "ok", service: "wwjing-server" });
}

module.exports = { getHealth };
