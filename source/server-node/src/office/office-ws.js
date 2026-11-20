const jwt = require("jsonwebtoken");
const { WebSocketServer } = require("ws");
const config = require("../config");
const { getRoom, verifyRoom, broadcast, removeClient } = require("./room-manager");

function attachOfficeWebSocket(server) {
  const wss = new WebSocketServer({ noServer: true });
  server.on("upgrade", (request, socket, head) => {
    if (new URL(request.url, "http://localhost").pathname !== "/api/office/ws") return;
    const requestUrl = new URL(request.url, "http://localhost");
    const token = requestUrl.searchParams.get("token")?.replace(/^Bearer\s+/i, "");
    try {
      request.user = token ? jwt.verify(token, config.jwtSecretKey) : { sub: `guest:${requestUrl.searchParams.get("guest") || "游客"}`, username: requestUrl.searchParams.get("guest") || "游客" };
    } catch {
      socket.destroy();
      return;
    }
    wss.handleUpgrade(request, socket, head, (client) => wss.emit("connection", client, request));
  });
  wss.on("connection", (client, request) => {
    const url = new URL(request.url, "http://localhost");
    const roomId = url.searchParams.get("roomId") || "main";
    const room = roomId === "main" ? getRoom("main") : verifyRoom(roomId, url.searchParams.get("password") || "");
    if (!room) {
      client.close(4003, "房间密码错误");
      return;
    }
    room.clients.add(client);
     const displayName = String(url.searchParams.get("displayName") || request.user.username || "用户").trim().slice(0, 40);
     const user = { id: String(request.user.sub), name: displayName || "用户" };
     client.officeUser = user;
      client.send(JSON.stringify({ type: "snapshot", user, topics: room.topics, locks: room.locks, columnWidths: room.columnWidths, revision: room.revision }));
    broadcast(room, { type: "presence", name: user.name, count: room.clients.size }, client);
    client.on("message", (raw) => {
      let message;
      try { message = JSON.parse(raw.toString()); } catch { return; }
       if (!message.type) return;
       if (message.type === "column:resize") {
         const index = Number(message.index);
         const width = Math.max(42, Math.min(800, Number(message.width)));
         if (!Number.isInteger(index) || !Number.isFinite(width)) return;
         room.columnWidths[index] = width;
         broadcast(room, { type: "column:resized", index, width }, client);
         return;
       }
       if (message.type === "cell:lock" || message.type === "cell:unlock") {
         const key = `${message.topicId}:${message.row}:${message.column}`;
         if (message.type === "cell:lock") {
           const owner = room.lockClients.get(key);
           if (owner && owner !== client) {
              client.send(JSON.stringify({ type: "cell:lock-rejected", key, user: room.locks[key] }));
             return;
           }
           room.locks[key] = user.name;
           room.lockClients.set(key, client);
           broadcast(room, { type: "cell:lock", key, user: user.name });
         } else if (room.lockClients.get(key) === client) {
           room.lockClients.delete(key);
           delete room.locks[key];
           broadcast(room, { type: "cell:unlock", key, user: user.name });
         }
         return;
      }
      if (message.type === "topic:create") {
        const template = room.topics[0];
        const topic = {
          id: `topic-${Date.now()}`,
          name: String(message.name || "未命名话题").slice(0, 80),
          cells: template ? JSON.parse(JSON.stringify(template.cells)) : [["任务记录", "负责人", "状态", "备注"]],
          cellAuthors: {},
          cellEditedAt: {},
          messages: []
        };
        room.topics.push(topic);
        broadcast(room, { type: "topic:created", topic });
      } else if (message.type === "cell:update") {
        const topic = room.topics.find((item) => item.id === message.topicId);
        if (!topic || !Number.isInteger(message.row) || !Number.isInteger(message.column)) return;
        topic.cells[message.row] ||= [];
         const key = `${message.topicId}:${message.row}:${message.column}`;
         if (room.lockClients.get(key) && room.lockClients.get(key) !== client) {
           client.send(JSON.stringify({ type: "cell:update:rejected", requestId: message.requestId, key, user: room.locks[key] }));
           return;
         }
          const nextValue = String(message.value || "").slice(0, 2000);
          const previousValue = String(topic.cells[message.row][message.column] || "");
          if (nextValue === previousValue) return;
          topic.cells[message.row][message.column] = nextValue;
          room.revision += 1;
         topic.cellAuthors ||= {};
         const authorKey = `${message.row}:${message.column}`;
         if (nextValue.trim()) {
           topic.cellAuthors[authorKey] = user.name;
           topic.cellEditedAt ||= {};
           topic.cellEditedAt[authorKey] = Date.now();
         } else {
           delete topic.cellAuthors[authorKey];
           topic.cellEditedAt ||= {};
           delete topic.cellEditedAt[authorKey];
         }
          const update = { ...message, type: "cell:updated", value: topic.cells[message.row][message.column], user: user.name, editedAt: topic.cellEditedAt?.[authorKey] || null, revision: room.revision };
         broadcast(room, update);
         client.send(JSON.stringify({ type: "cell:update:ack", requestId: message.requestId, revision: room.revision }));
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
