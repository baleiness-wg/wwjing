const jwt = require("jsonwebtoken");
const { WebSocketServer } = require("ws");
const config = require("../config");
const { verifyRoom, broadcast, removeClient, countOnlineUsers, initializeTopic, defaultColumnWidths, renameClientAuthors } = require("./room-manager");
const { validCell, createRateLimiter } = require("./write-limits");

function attachOfficeWebSocket(server) {
  const wss = new WebSocketServer({ noServer: true });
  const allowWrites = createRateLimiter({ limit: 300, windowMs: 10000 });
  // 及时回收断网后无法正常关闭的连接，避免在线人数和编辑锁长期残留。
  const heartbeat = setInterval(() => {
    for (const client of wss.clients) {
      if (client.readyState !== 1) continue;
      if (client.officeAlive === false) {
        client.terminate();
        continue;
      }
      client.officeAlive = false;
      client.ping();
    }
  }, 30000);
  heartbeat.unref();
  server.on("close", () => clearInterval(heartbeat));
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
    const roomId = url.searchParams.get("roomId");
    const room = roomId ? verifyRoom(roomId, url.searchParams.get("password") || "") : null;
    if (!room) {
      client.close(4003, "房间密码错误");
      return;
    }
    room.locks ||= {};
    if (!(room.lockClients instanceof Map)) room.lockClients = new Map();
    room.columnWidths ||= [58, 58, 180, 380, 58, 58, 58, ...Array(19).fill(58)];
     room.clients.add(client);
     client.officeAlive = true;
     client.on("pong", () => { client.officeAlive = true; });
     room.columnWidths ||= [58, 58, 180, 380, 58, 58, 58, ...Array(19).fill(58)];
     const displayName = String(url.searchParams.get("displayName") || request.user.username || "用户").trim().slice(0, 40);
     const user = { id: String(request.user.sub), name: displayName || "用户" };
     client.officeUser = user;
     client.officeClientId = String(url.searchParams.get("clientId") || "").slice(0, 100);
      client.send(JSON.stringify({ type: "snapshot", user, topics: room.topics, locks: room.locks, columnWidths: room.columnWidths, revision: room.revision, online: countOnlineUsers(room) }));
    broadcast(room, { type: "presence", name: user.name, count: countOnlineUsers(room) }, client);
    client.on("message", (raw) => {
      let message;
      try { message = JSON.parse(raw.toString()); } catch { return; }
       if (!message.type) return;
       if (!allowWrites(request.socket.remoteAddress || "unknown")) {
         client.send(JSON.stringify({ type: "write:rate-limited", message: "操作过于频繁，请稍后重试" }));
         client.close(4429, "操作过于频繁");
         return;
       }
       if (message.type === "user:rename") {
         const nextName = String(message.name || "").trim().slice(0, 40);
         if (!nextName) return;
         const previousName = String(message.oldName || client.officeUser?.name || "用户").trim().slice(0, 40);
         client.officeUser.name = nextName;
         const updatedRooms = renameClientAuthors(client.officeClientId, previousName, nextName, room);
         for (const updatedRoom of updatedRooms) {
           broadcast(updatedRoom, { type: "user:renamed", oldName: previousName, name: nextName, clientId: client.officeClientId, revision: updatedRoom.revision });
         }
         client.send(JSON.stringify({ type: "user:rename:ack", oldName: previousName, name: nextName }));
         client.send(JSON.stringify({ type: "snapshot", user: client.officeUser, topics: room.topics, locks: room.locks, columnWidths: room.columnWidths, revision: room.revision, online: countOnlineUsers(room) }));
         return;
       }
       if (message.type === "column:resize") {
         const index = Number(message.index);
         const width = Math.max(42, Math.min(800, Number(message.width)));
          if (!Number.isInteger(index) || index < 0 || index > 25 || !Number.isFinite(width)) return;
         room.columnWidths[index] = width;
         broadcast(room, { type: "column:resized", index, width }, client);
         return;
       }
        if (message.type === "cell:lock" || message.type === "cell:unlock") {
          if (!validCell(message.row, message.column) || !room.topics.some((topic) => topic.id === message.topicId)) return;
         const key = `${message.topicId}:${message.row}:${message.column}`;
         if (message.type === "cell:lock") {
           const owner = room.lockClients.get(key);
           if (owner && owner !== client) {
              client.send(JSON.stringify({ type: "cell:lock-rejected", key, user: room.locks[key] }));
             return;
           }
           room.locks[key] = user.name;
           room.lockClients.set(key, client);
            broadcast(room, { type: "cell:editing", key, user: user.name });
         } else if (room.lockClients.get(key) === client) {
           room.lockClients.delete(key);
           delete room.locks[key];
            broadcast(room, { type: "cell:editing-end", key, user: user.name });
         }
         return;
      }
       if (message.type === "sheet:initialize") {
         const topic = room.topics.find((item) => item.id === message.topicId);
         if (!topic) return;
         initializeTopic(topic);
         Object.keys(room.locks).filter((key) => key.startsWith(`${topic.id}:`)).forEach((key) => delete room.locks[key]);
         for (const [key, owner] of room.lockClients) {
           if (key.startsWith(`${topic.id}:`)) room.lockClients.delete(key);
         }
         room.columnWidths = [...defaultColumnWidths];
         room.revision = (room.revision || 0) + 1;
         const initialized = { type: "sheet:initialized", topic, columnWidths: room.columnWidths, user: user.name, suppressUnread: true, revision: room.revision };
         broadcast(room, initialized, client);
         client.send(JSON.stringify({ ...initialized, requestId: message.requestId }));
       } else if (message.type === "sheet:replace") {
         const topic = room.topics.find((item) => item.id === message.topicId);
         if (!topic || !Array.isArray(message.cells)) return;
         const cells = message.cells.slice(0, 500).map((row) => (Array.isArray(row) ? row : [])
           .slice(0, 26).map((value) => String(value ?? "").slice(0, 2000)));
         if (!cells.length) return;
         topic.cells = cells;
         topic.cellStyles = message.cellStyles && typeof message.cellStyles === "object" ? message.cellStyles : {};
         topic.imported = message.imported === true;
         topic.rowHeights = message.rowHeights && typeof message.rowHeights === "object" ? message.rowHeights : {};
         topic.cellAuthors = {};
         topic.cellAuthorIds = {};
         topic.cellEditedAt = {};
         topic.messages = [];
         Object.keys(room.locks).filter((key) => key.startsWith(`${topic.id}:`)).forEach((key) => delete room.locks[key]);
         for (const [key] of room.lockClients) if (key.startsWith(`${topic.id}:`)) room.lockClients.delete(key);
         room.columnWidths = Array.isArray(message.columnWidths) ? message.columnWidths.slice(0, 26).map((value) => Math.max(42, Math.min(800, Number(value) || 58))) : [...defaultColumnWidths];
         room.revision = (room.revision || 0) + 1;
         const replaced = { type: "sheet:replaced", topic, columnWidths: room.columnWidths, user: user.name, suppressUnread: true, revision: room.revision };
         broadcast(room, replaced, client);
         client.send(JSON.stringify({ ...replaced, requestId: message.requestId }));
       } else if (message.type === "topic:create") {
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
        broadcast(room, { type: "topic:created", topic, user: user.name }, client);
      } else if (message.type === "cell:update") {
        const topic = room.topics.find((item) => item.id === message.topicId);
         if (!topic || !validCell(message.row, message.column)) return;
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
           room.revision = (room.revision || 0) + 1;
         topic.cellAuthors ||= {};
         const authorKey = `${message.row}:${message.column}`;
         if (nextValue.trim()) {
            topic.cellAuthors[authorKey] = user.name;
            if (client.officeClientId) (topic.cellAuthorIds ||= {})[authorKey] = client.officeClientId;
            else if (topic.cellAuthorIds) delete topic.cellAuthorIds[authorKey];
           topic.cellEditedAt ||= {};
           topic.cellEditedAt[authorKey] = Date.now();
         } else {
            delete topic.cellAuthors[authorKey];
            if (topic.cellAuthorIds) delete topic.cellAuthorIds[authorKey];
           topic.cellEditedAt ||= {};
           delete topic.cellEditedAt[authorKey];
         }
           const update = { ...message, type: "cell:updated", value: topic.cells[message.row][message.column], user: user.name, clientId: client.officeClientId, editedAt: topic.cellEditedAt?.[authorKey] || null, revision: room.revision };
          broadcast(room, update, client);
         client.send(JSON.stringify({ type: "cell:update:ack", requestId: message.requestId, revision: room.revision }));
        } else if (message.type === "cell:draft") {
          if (!validCell(message.row, message.column)) return;
         const key = `${message.topicId}:${message.row}:${message.column}`;
         if (room.lockClients.get(key) !== client) return;
         broadcast(room, { type: "cell:draft", ...message, value: String(message.value || "").slice(0, 2000), user: user.name }, client);
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
      if (room.clients.size) broadcast(room, { type: "presence", name: user.name, count: countOnlineUsers(room) });
    });
  });
}

module.exports = { attachOfficeWebSocket };
