// HTTP 和 WebSocket 分别计数，按直接连接的来源地址限制写入频率。
const MAX_ROW = 9999;
const MAX_COLUMN = 25;

function validCell(row, column) {
  return Number.isInteger(row) && row >= 0 && row <= MAX_ROW &&
    Number.isInteger(column) && column >= 0 && column <= MAX_COLUMN;
}

function createRateLimiter({ limit, windowMs, maxEntries = 10000, now = Date.now }) {
  const entries = new Map();
  return (key) => {
    const time = now();
    let entry = entries.get(key);
    if (!entry || time >= entry.resetAt) {
      if (!entry && entries.size >= maxEntries) {
        for (const [id, value] of entries) if (time >= value.resetAt) entries.delete(id);
        if (entries.size >= maxEntries) return false;
      }
      entry = { count: 0, resetAt: time + windowMs };
      entries.set(key, entry);
    }
    entry.count += 1;
    return entry.count <= limit;
  };
}

module.exports = { MAX_ROW, MAX_COLUMN, validCell, createRateLimiter };
