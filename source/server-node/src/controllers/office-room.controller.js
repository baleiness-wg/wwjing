const { findRoomByName, createNamedRoom, getRoom, removeRoom, countOnlineUsers } = require("../office/room-manager");

function list(req, res) {
  const name = typeof req.query.name === "string" ? req.query.name.trim() : "";
  if (!name || name.length > 80) return res.status(400).json({ message: "请输入完整房间名称" });
  const room = findRoomByName(name);
  if (!room) return res.status(404).json({ message: "未找到该房间" });
  return res.json({ room: { id: room.id, name: room.name, protected: Boolean(room.password), online: countOnlineUsers(room) } });
}

function create(req, res) {
  const name = String(req.body?.name || "").trim();
  const password = String(req.body?.password || "");
  if (!name || name.length > 80 || password.length < 4 || password.length > 120) return res.status(400).json({ message: "房间名称须为 1 至 80 个字符，密码须为 4 至 120 个字符" });
  const room = createNamedRoom(name, password, String(req.auth.sub), req.auth.username);
  if (!room) return res.status(409).json({ message: "房间名称已存在，请使用其他名称" });
  res.status(201).json({ room: { id: room.id, name: room.name, protected: true, online: 0 } });
}

function updatePassword(req, res) {
  const room = getRoom(req.params.id);
  const guestName = decodeOfficeGuest(req.headers["x-office-guest"]);
  const ownerMatches = room && (
    room.ownerId === String(req.auth.sub) ||
    room.ownerName === req.auth.username ||
    room.ownerId === `guest:${guestName}` ||
    room.ownerName === guestName
  );
  if (!ownerMatches) return res.status(403).json({ message: "无权修改此房间" });
  const password = String(req.body?.password || "");
  if (password.length < 4) return res.status(400).json({ message: "密码至少 4 位" });
  room.password = password.slice(0, 120);
  res.json({ ok: true });
}

function decodeOfficeGuest(value) {
  try { return decodeURIComponent(String(value || "")).trim().slice(0, 40); } catch { return ""; }
}

function remove(req, res) {
  const room = getRoom(req.params.id);
  if (!room || (room.ownerId !== String(req.auth.sub) && room.ownerName !== req.auth.username)) return res.status(403).json({ message: "无权删除此房间" });
  removeRoom(req.params.id);
  res.status(204).end();
}

module.exports = { list, create, updatePassword, remove };
