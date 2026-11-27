const { verifyRoom, broadcast } = require("../office/room-manager");
const { validCell } = require("../office/write-limits");

function snapshot(req, res) {
  res.set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate");
  res.set("Pragma", "no-cache");
  res.set("Expires", "0");
  const roomId = req.headers["x-office-room"];
  const room = roomId ? verifyRoom(roomId, roomPassword(req)) : null;
  if (!room) return res.status(403).json({ message: "房间密码错误" });
  res.json({
    user: { id: String(req.auth.sub), name: req.auth.username || "用户" },
    room: { id: room.id, name: room.name, protected: Boolean(room.password), online: room.clients.size },
    topics: room.topics,
    locks: room.locks,
    columnWidths: room.columnWidths,
    revision: room.revision
  });
}

module.exports = { snapshot };

function updateCell(req, res) {
  const { topicId, row, column, value } = req.body || {};
  const roomId = req.headers["x-office-room"];
  const room = roomId ? verifyRoom(roomId, roomPassword(req)) : null;
  if (!room) return res.status(403).json({ message: "房间密码错误" });
  const topic = room.topics.find((item) => item.id === topicId);
  if (!topic || !validCell(row, column)) {
    return res.status(400).json({ message: "无效的单元格" });
  }
  topic.cells[row] ||= [];
  const nextValue = String(value || "").slice(0, 2000);
  const previousValue = String(topic.cells[row][column] || "");
  if (nextValue === previousValue) return res.json({ ok: true, changed: false });
  topic.cells[row][column] = nextValue;
  room.revision = (room.revision || 0) + 1;
  topic.cellAuthors ||= {};
  const displayName = decodeOfficeHeader(req.headers["x-office-display-name"], req.auth.username || "用户");
  const authorKey = `${row}:${column}`;
  topic.cellEditedAt ||= {};
  if (nextValue.trim()) {
    topic.cellAuthors[authorKey] = displayName;
    const clientId = String(req.headers["x-office-client-id"] || "").slice(0, 100);
    if (clientId) (topic.cellAuthorIds ||= {})[authorKey] = clientId;
    else if (topic.cellAuthorIds) delete topic.cellAuthorIds[authorKey];
    topic.cellEditedAt[authorKey] = Date.now();
  } else {
    delete topic.cellAuthors[authorKey];
    if (topic.cellAuthorIds) delete topic.cellAuthorIds[authorKey];
    delete topic.cellEditedAt[authorKey];
  }
  broadcast(room, { type: "cell:updated", topicId, row, column, value: topic.cells[row][column], user: displayName, clientId: String(req.headers["x-office-client-id"] || "").slice(0, 100), editedAt: topic.cellEditedAt[authorKey] || null, revision: room.revision });
  return res.json({ ok: true, revision: room.revision });
}

module.exports.updateCell = updateCell;

function updateLock(req, res) {
  const { topicId, row, column, locked } = req.body || {};
  const roomId = req.headers["x-office-room"] || "main";
  const room = roomId ? verifyRoom(roomId, roomPassword(req)) : null;
  if (!room) return res.status(403).json({ message: "房间密码错误" });
  if (!validCell(row, column) || !room.topics.some((topic) => topic.id === topicId)) return res.status(400).json({ message: "无效的单元格" });
  room.locks ||= {};
  const key = `${topicId}:${row}:${column}`;
  const user = decodeOfficeHeader(req.headers["x-office-display-name"], req.auth.username || "用户");
  if (locked) {
    if (room.locks[key] && room.locks[key] !== user) return res.status(409).json({ user: room.locks[key] });
    room.locks[key] = user;
  } else if (room.locks[key] === user) delete room.locks[key];
  broadcast(room, { type: locked ? "cell:editing" : "cell:editing-end", key, user });
  res.json({ ok: true, key, user });
}

module.exports.updateLock = updateLock;

function decodeOfficeHeader(value, fallback) {
  try { return decodeURIComponent(String(value || fallback)).trim().slice(0, 40) || fallback; } catch { return fallback; }
}

function roomPassword(req) {
  const password = String(req.headers["x-office-password"] || "");
  if (req.headers["x-office-password-encoding"] !== "uri") return password;
  try { return decodeURIComponent(password); } catch { return null; }
}
