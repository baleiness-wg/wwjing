const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const WebSocket = require("ws");
const app = require("../src/app");
const { attachOfficeWebSocket } = require("../src/office/office-ws");
const { createNamedRoom, removeRoom } = require("../src/office/room-manager");

test("房间密码支持中文和特殊字符，并兼容旧版未编码请求", async (t) => {
  const password = "密码 %&+ test";
  const room = createNamedRoom("密码测试", password, "owner", "owner");
  const legacyRoom = createNamedRoom("旧密码测试", "abc%20def", "owner", "owner");
  const server = http.createServer(app);
  attachOfficeWebSocket(server);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(async () => {
    removeRoom(room.id);
    removeRoom(legacyRoom.id);
    await new Promise((resolve) => server.close(resolve));
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  const headers = { "Content-Type": "application/json", "X-Office-Room": room.id, "X-Office-Password": encodeURIComponent(password), "X-Office-Password-Encoding": "uri" };
  assert.equal((await fetch(`${base}/api/office/snapshot`, { headers })).status, 200);
  for (const [path, body] of [
    ["lock", { topicId: "topic-1", row: 2, column: 0, locked: true }],
    ["cell", { topicId: "topic-1", row: 2, column: 0, value: "测试" }]
  ]) {
    assert.equal((await fetch(`${base}/api/office/${path}`, { method: "POST", headers, body: JSON.stringify(body) })).status, 200);
  }
  assert.equal((await fetch(`${base}/api/office/snapshot`, { headers: { ...headers, "X-Office-Password": "wrong" } })).status, 403);
  assert.equal((await fetch(`${base}/api/office/snapshot`, { headers: { ...headers, "X-Office-Password": "%" } })).status, 403);
  assert.equal((await fetch(`${base}/api/office/snapshot`, { headers: { "X-Office-Room": legacyRoom.id, "X-Office-Password": "abc%20def" } })).status, 200);

  const ws = new WebSocket(`${base.replace("http", "ws")}/api/office/ws?roomId=${encodeURIComponent(room.id)}&password=${encodeURIComponent(password)}&guest=other`);
  t.after(() => ws.terminate());
  const snapshot = await new Promise((resolve, reject) => {
    ws.once("message", (data) => resolve(JSON.parse(data)));
    ws.once("error", reject);
  });
  assert.equal(snapshot.type, "snapshot");
  ws.terminate();
});
