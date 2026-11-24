const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const WebSocket = require("ws");
const app = require("../src/app");
const { attachOfficeWebSocket } = require("../src/office/office-ws");
const { createNamedRoom, removeRoom } = require("../src/office/room-manager");

test("Office 限制异常坐标及高频写入，正常协作仍可保存", async (t) => {
  const room = createNamedRoom("限流测试", "test-password", "owner", "owner");
  const server = http.createServer(app);
  attachOfficeWebSocket(server);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  t.after(async () => {
    removeRoom(room.id);
    await new Promise((resolve) => server.close(resolve));
  });
  const headers = { "Content-Type": "application/json", "X-Office-Room": room.id, "X-Office-Password": "test-password" };
  const write = (row, column, value) => fetch(`${base}/api/office/cell`, {
    method: "POST", headers, body: JSON.stringify({ topicId: "topic-1", row, column, value })
  });

  assert.equal((await write(2, 0, "正常编辑")).status, 200);
  assert.equal(room.topics[0].cells[2][0], "正常编辑");
  assert.equal((await write(1000000000, 0, "异常")).status, 400);
  assert.equal((await write(1, 26, "异常")).status, 400);
  assert.ok(room.topics[0].cells.length < 1000);

  const ws = new WebSocket(`${base.replace("http", "ws")}/api/office/ws?roomId=${encodeURIComponent(room.id)}&password=test-password&guest=test`);
  t.after(() => ws.terminate());
  await new Promise((resolve, reject) => { ws.once("open", resolve); ws.once("error", reject); });
  const messages = [];
  ws.on("message", (data) => messages.push(JSON.parse(data)));
  ws.send(JSON.stringify({ type: "cell:update", topicId: "topic-1", row: 1000000000, column: 0, value: "异常" }));
  for (let index = 0; index < 301; index += 1) {
    ws.send(JSON.stringify({ type: "cell:update", topicId: "topic-1", row: 3, column: 0, value: String(index) }));
  }
  await new Promise((resolve) => ws.once("close", resolve));
  assert.ok(messages.some((message) => message.type === "write:rate-limited"));
  assert.ok(room.topics[0].cells.length < 1000);
  assert.notEqual(room.topics[0].cells[3][0], "300");

  let limited = false;
  for (let index = 0; index < 125; index += 1) {
    if ((await write(4, 0, String(index))).status === 429) { limited = true; break; }
  }
  assert.equal(limited, true);
});

test("限流时间窗口结束后恢复写入", () => {
  const { createRateLimiter } = require("../src/office/write-limits");
  let now = 0;
  const allow = createRateLimiter({ limit: 2, windowMs: 100, now: () => now });
  assert.equal(allow("client"), true);
  assert.equal(allow("client"), true);
  assert.equal(allow("client"), false);
  now = 100;
  assert.equal(allow("client"), true);
});
