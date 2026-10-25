import test from "node:test";
import assert from "node:assert/strict";

globalThis.localStorage = {
  getItem(key) {
    return key === "wwjing_token" ? "Bearer test-token" : null;
  },
  removeItem() {}
};

const requests = [];
globalThis.fetch = async (url, options = {}) => {
  requests.push({ url, options });
  return new Response(JSON.stringify({ items: [], total: 0, page: 2, pageSize: 12 }), {
    status: 200,
    headers: { "Content-Type": "application/json" }
  });
};

const { createBookmarkItem, getBookmarkItems, updateBookmarkFolder } = await import("../src/api/bookmarks.js");

test("收藏查询序列化筛选和分页参数并携带登录令牌", async () => {
  await getBookmarkItems({ folderId: "8", query: "Flutter", page: 2, pageSize: 12 });
  const request = requests.shift();
  const url = new URL(request.url, "https://example.test");

  assert.equal(url.pathname, "/api/bookmarks/items");
  assert.equal(url.searchParams.get("folderId"), "8");
  assert.equal(url.searchParams.get("query"), "Flutter");
  assert.equal(url.searchParams.get("page"), "2");
  assert.equal(request.options.headers.get("Authorization"), "Bearer test-token");
});

test("收藏和目录写请求符合服务端 JSON 契约", async () => {
  await createBookmarkItem({
    sourceUrl: "https://example.com",
    title: null,
    description: null,
    folderId: null,
    allowDuplicate: true
  });
  await updateBookmarkFolder("3", { parentId: null, position: 2 });

  const createRequest = requests.shift();
  assert.equal(createRequest.options.method, "POST");
  assert.deepEqual(JSON.parse(createRequest.options.body), {
    sourceUrl: "https://example.com",
    title: null,
    description: null,
    folderId: null,
    allowDuplicate: true
  });

  const updateRequest = requests.shift();
  assert.equal(updateRequest.url, "/api/bookmarks/folders/3");
  assert.equal(updateRequest.options.method, "PATCH");
  assert.deepEqual(JSON.parse(updateRequest.options.body), { parentId: null, position: 2 });
});
