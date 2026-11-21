const { listRooms, createNamedRoom, getRoom, removeRoom } = require("../office/room-manager");

function list(req, res) { res.json({ rooms: listRooms() }); }

function create(req, res) {
  const name = String(req.body?.name || "").trim();
  const password = String(req.body?.password || "");
  if (!name || password.length < 4) return res.status(400).json({ message: "房间名称不能为空，密码至少 4 位" });
  const room = createNamedRoom(name.slice(0, 80), password.slice(0, 120), String(req.auth.sub), req.auth.username);
  res.status(201).json({ room: { id: room.id, name: room.name, protected: true, online: 0 } });
}

function updatePassword(req, res) {
  const room = getRoom(req.params.id);
  if (!room || (room.ownerId !== String(req.auth.sub) && room.ownerName !== req.auth.username)) return res.status(403).json({ message: "无权修改此房间" });
  const password = String(req.body?.password || "");
  if (password.length < 4) return res.status(400).json({ message: "密码至少 4 位" });
  room.password = password.slice(0, 120);
  res.json({ ok: true });
}

function remove(req, res) {
  const room = getRoom(req.params.id);
  if (!room || (room.ownerId !== String(req.auth.sub) && room.ownerName !== req.auth.username)) return res.status(403).json({ message: "无权删除此房间" });
  removeRoom(req.params.id);
  res.status(204).end();
}

module.exports = { list, create, updatePassword, remove };
