const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const WebSocket = require("ws");
const app = require("../src/app");
const { attachOfficeWebSocket } = require("../src/office/office-ws");
const { createNamedRoom, removeRoom } = require("../src/office/room-manager");

test("改名同步本人跨房间的作者，保留同名其他用户", async (t) => {
  const first = createNamedRoom("房间一", "pass", "owner", "owner");
  const second = createNamedRoom("房间二", "pass", "owner", "owner");
  const server = http.createServer(app);
  attachOfficeWebSocket(server);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(async () => {
    removeRoom(first.id);
    removeRoom(second.id);
    await new Promise((resolve) => server.close(resolve));
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const [room, clientId, row] of [[first, "client-a", 2], [second, "client-a", 2], [second, "client-b", 3]]) {
    const response = await fetch(`${base}/api/office/cell`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Office-Room": room.id, "X-Office-Password": "pass", "X-Office-Display-Name": encodeURIComponent("同名"), "X-Office-Client-Id": clientId },
      body: JSON.stringify({ topicId: "topic-1", row, column: 0, value: `编辑${row}` })
    });
    assert.equal(response.status, 200);
  }
  first.topics[0].cellAuthors["4:0"] = "同名";
  second.topics[0].cellAuthors["4:0"] = "同名";
  const ws = new WebSocket(`${base.replace("http", "ws")}/api/office/ws?roomId=${first.id}&password=pass&guest=guest&displayName=${encodeURIComponent("新名")}&clientId=client-a`);
  t.after(() => ws.terminate());
  await new Promise((resolve, reject) => { ws.once("message", resolve); ws.once("error", reject); });
  const ack = new Promise((resolve) => ws.on("message", (data) => {
    const message = JSON.parse(data);
    if (message.type === "user:rename:ack") resolve(message);
  }));
  ws.send(JSON.stringify({ type: "user:rename", oldName: "同名", name: "新名" }));
  await ack;
  assert.equal(first.topics[0].cellAuthors["2:0"], "新名");
  assert.equal(first.topics[0].cellAuthors["4:0"], "新名");
  assert.equal(second.topics[0].cellAuthors["2:0"], "新名");
  assert.equal(second.topics[0].cellAuthors["3:0"], "同名");
  assert.equal(second.topics[0].cellAuthors["4:0"], "同名");
  ws.terminate();
});
