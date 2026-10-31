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

const {
  createBookmarkItem,
  detectBookmarkMetadata,
  getBookmarkItems,
  updateBookmarkFolder,
  updateBookmarkItem
} = await import("../src/api/bookmarks.js");

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
    coverUrl: null,
    folderId: null,
    allowDuplicate: true
  });
  await updateBookmarkItem("9", { coverUrl: "https://example.com/cover.jpg" });
  await updateBookmarkFolder("3", { parentId: null, position: 2 });

  const createRequest = requests.shift();
  assert.equal(createRequest.options.method, "POST");
  assert.deepEqual(JSON.parse(createRequest.options.body), {
    sourceUrl: "https://example.com",
    title: null,
    description: null,
    coverUrl: null,
    folderId: null,
    allowDuplicate: true
  });

  const itemUpdateRequest = requests.shift();
  assert.equal(itemUpdateRequest.url, "/api/bookmarks/items/9");
  assert.equal(itemUpdateRequest.options.method, "PATCH");
  assert.deepEqual(JSON.parse(itemUpdateRequest.options.body), { coverUrl: "https://example.com/cover.jpg" });

  const folderUpdateRequest = requests.shift();
  assert.equal(folderUpdateRequest.url, "/api/bookmarks/folders/3");
  assert.equal(folderUpdateRequest.options.method, "PATCH");
  assert.deepEqual(JSON.parse(folderUpdateRequest.options.body), { parentId: null, position: 2 });
});

test("网页元数据检测请求符合服务端契约", async () => {
  await detectBookmarkMetadata("https://example.com/article");
  const request = requests.shift();

  assert.equal(request.url, "/api/bookmarks/metadata");
  assert.equal(request.options.method, "POST");
  assert.equal(request.options.headers.get("Content-Type"), "application/json");
  assert.deepEqual(JSON.parse(request.options.body), { sourceUrl: "https://example.com/article" });
});
