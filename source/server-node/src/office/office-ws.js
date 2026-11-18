const jwt = require("jsonwebtoken");
const { WebSocketServer } = require("ws");
const config = require("../config");
const { getRoom, broadcast, removeClient } = require("./room-manager");

function attachOfficeWebSocket(server) {
  const wss = new WebSocketServer({ noServer: true });
  server.on("upgrade", (request, socket, head) => {
    if (new URL(request.url, "http://localhost").pathname !== "/api/office/ws") return;
    const token = new URL(request.url, "http://localhost").searchParams.get("token")?.replace(/^Bearer\s+/i, "");
    try {
      request.user = jwt.verify(token, config.jwtSecretKey);
    } catch {
      socket.destroy();
      return;
    }
    wss.handleUpgrade(request, socket, head, (client) => wss.emit("connection", client, request));
  });
  wss.on("connection", (client, request) => {
    const roomId = "main";
    const room = getRoom(roomId);
    room.clients.add(client);
    const user = { id: String(request.user.sub), name: request.user.username || "用户" };
    client.send(JSON.stringify({ type: "snapshot", user, topics: room.topics }));
    broadcast(room, { type: "presence", name: user.name, count: room.clients.size }, client);
    client.on("message", (raw) => {
      let message;
      try { message = JSON.parse(raw.toString()); } catch { return; }
      if (!message.type) return;
      if (message.type === "topic:create") {
        const topic = { id: `topic-${Date.now()}`, name: String(message.name || "未命名话题").slice(0, 80), cells: [["任务记录", "负责人", "状态", "备注"]], messages: [] };
        room.topics.push(topic);
        broadcast(room, { type: "topic:created", topic });
      } else if (message.type === "cell:update") {
        const topic = room.topics.find((item) => item.id === message.topicId);
        if (!topic || !Number.isInteger(message.row) || !Number.isInteger(message.column)) return;
        topic.cells[message.row] ||= [];
        topic.cells[message.row][message.column] = String(message.value || "").slice(0, 2000);
        topic.cellAuthors ||= {};
        topic.cellAuthors[`${message.row}:${message.column}`] = user.name;
        broadcast(room, { ...message, type: "cell:updated", user: user.name }, client);
      } else if (message.type === "chat:send") {
        const topic = room.topics.find((item) => item.id === message.topicId);
        if (!topic) return;
        const chat = { author: user.name, text: String(message.text || "").slice(0, 2000), at: Date.now() };
        if (!chat.text) return;
        topic.messages.push(chat);
        broadcast(room, { type: "chat:message", topicId: topic.id, message: chat });
      }
    });
    client.on("close", () => {
      removeClient(roomId, client);
      if (room.clients.size) broadcast(room, { type: "presence", name: user.name, count: room.clients.size });
    });
  });
}

module.exports = { attachOfficeWebSocket };
