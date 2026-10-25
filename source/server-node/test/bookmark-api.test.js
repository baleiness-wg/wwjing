const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const jwt = require("jsonwebtoken");
const app = require("../src/app");
const config = require("../src/config");
const folderService = require("../src/services/bookmark-folder.service");
const itemService = require("../src/services/bookmark-item.service");

async function withServer(callback) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    await callback(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

test("bookmark routes reject unauthenticated requests", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/bookmarks/folders`);
    assert.equal(response.status, 401);
  });
});

test("bookmark CRUD routes use JWT subject rather than request data", async () => {
  const originalFolders = { ...folderService };
  const originalItems = { ...itemService };
  const users = [];
  folderService.list = async (userId) => { users.push(userId); return []; };
  folderService.create = async (userId) => { users.push(userId); return { id: "5" }; };
  folderService.update = async (userId) => { users.push(userId); return { id: "5" }; };
  folderService.remove = async (userId) => { users.push(userId); };
  itemService.list = async (userId) => {
    users.push(userId);
    return { items: [], total: 0, page: 1, pageSize: 20 };
  };
  itemService.create = async (userId) => {
    users.push(userId);
    return { id: "8", sourceUrl: "https://example.com", description: null };
  };
  itemService.get = async (userId) => { users.push(userId); return { id: "8" }; };
  itemService.update = async (userId) => { users.push(userId); return { id: "8" }; };
  itemService.remove = async (userId) => { users.push(userId); };
  const token = jwt.sign({ sub: "42" }, config.jwtSecretKey, { algorithm: "HS256" });

  try {
    await withServer(async (baseUrl) => {
      const headers = { Authorization: `Bearer ${token}` };
      const jsonHeaders = { ...headers, "Content-Type": "application/json" };
      const requests = [
        ["/api/bookmarks/folders?userId=999", {}],
        ["/api/bookmarks/folders", { method: "POST", headers: jsonHeaders, body: "{}" }],
        ["/api/bookmarks/folders/5", { method: "PATCH", headers: jsonHeaders, body: "{}" }],
        ["/api/bookmarks/folders/5", { method: "DELETE", headers }],
        ["/api/bookmarks/items?userId=999", {}],
        ["/api/bookmarks/items", {
          method: "POST",
          headers: jsonHeaders,
          body: JSON.stringify({ userId: "999", sourceUrl: "https://example.com" })
        }],
        ["/api/bookmarks/items/8", {}],
        ["/api/bookmarks/items/8", { method: "PATCH", headers: jsonHeaders, body: "{}" }],
        ["/api/bookmarks/items/8", { method: "DELETE", headers }]
      ];
      const expectedStatuses = [200, 201, 200, 204, 200, 201, 200, 200, 204];
      for (let index = 0; index < requests.length; index += 1) {
        const [path, options] = requests[index];
        const response = await fetch(`${baseUrl}${path}`, {
          headers,
          ...options
        });
        assert.equal(response.status, expectedStatuses[index], path);
      }
    });
    assert.deepEqual(users, Array(9).fill("42"));
  } finally {
    Object.assign(folderService, originalFolders);
    Object.assign(itemService, originalItems);
  }
});
