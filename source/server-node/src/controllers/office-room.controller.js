const { listRooms, createNamedRoom } = require("../office/room-manager");

function list(req, res) { res.json({ rooms: listRooms() }); }

function create(req, res) {
  const name = String(req.body?.name || "").trim();
  const password = String(req.body?.password || "");
  if (!name || password.length < 4) return res.status(400).json({ message: "房间名称不能为空，密码至少 4 位" });
  const room = createNamedRoom(name.slice(0, 80), password.slice(0, 120));
  res.status(201).json({ room: { id: room.id, name: room.name, protected: true, online: 0 } });
}

module.exports = { list, create };
