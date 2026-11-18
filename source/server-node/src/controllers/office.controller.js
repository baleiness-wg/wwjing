const { getRoom, broadcast } = require("../office/room-manager");

function snapshot(req, res) {
  res.set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate");
  res.set("Pragma", "no-cache");
  res.set("Expires", "0");
  const room = getRoom("main");
  res.json({
    user: { id: String(req.auth.sub), name: req.auth.username || "用户" },
    topics: room.topics,
    locks: room.locks,
    revision: room.revision
  });
}

module.exports = { snapshot };

function updateCell(req, res) {
  const { topicId, row, column, value } = req.body || {};
  const room = getRoom("main");
  const topic = room.topics.find((item) => item.id === topicId);
  if (!topic || !Number.isInteger(row) || !Number.isInteger(column)) {
    return res.status(400).json({ message: "无效的单元格" });
  }
  topic.cells[row] ||= [];
  topic.cells[row][column] = String(value || "").slice(0, 2000);
  room.revision += 1;
  topic.cellAuthors ||= {};
  topic.cellAuthors[`${row}:${column}`] = req.auth.username || "用户";
  broadcast(room, { type: "cell:updated", topicId, row, column, value: topic.cells[row][column], user: req.auth.username || "用户", revision: room.revision });
  return res.json({ ok: true, revision: room.revision });
}

module.exports.updateCell = updateCell;
