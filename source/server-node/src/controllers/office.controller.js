const { getRoom } = require("../office/room-manager");

function snapshot(req, res) {
  const room = getRoom("main");
  res.json({
    user: { id: String(req.auth.sub), name: req.auth.username || "用户" },
    topics: room.topics
  });
}

module.exports = { snapshot };
