const test = require("node:test");
const assert = require("node:assert/strict");
const itemService = require("../src/services/bookmark-item.service");
const itemModel = require("../src/models/bookmark-item.model");
const folderModel = require("../src/models/bookmark-folder.model");
const itemId = "99999999999999999999999999999999";
const folderId = "88888888888888888888888888888888";

test("normalizeUrl removes fragments, default ports, tracking parameters, and trailing slashes", () => {
  const result = itemService.normalizeUrl(
    "HTTPS://Example.COM:443/path/?b=2&utm_source=feed&a=1#part"
  );
  assert.deepEqual(result, {
    normalizedUrl: "https://example.com/path?a=1&b=2",
    sourceHost: "example.com"
  });
  assert.equal(
    itemService.normalizeUrl("https://example.com/path?b=2&a=1&utm_medium=share#other").normalizedUrl,
    result.normalizedUrl
  );
});

test("normalizeUrl rejects non-http links", () => {
  assert.throws(
    () => itemService.normalizeUrl("javascript:alert(1)"),
    (error) => error.code === "INVALID_URL" && error.status === 400
  );
});

test("create requires explicit confirmation for an equivalent duplicate", async () => {
  const originalDuplicate = itemModel.findDuplicate;
  const originalCreate = itemModel.create;
  itemModel.findDuplicate = async (userId, normalizedUrl) => ({
     id: itemId, title: "existing", folderId: null, userId, normalizedUrl
  });
  let created;
  itemModel.create = async (userId, values) => {
    created = { userId, ...values };
     return { id: itemId, ...values };
  };

  try {
    await assert.rejects(
      itemService.create("7", { sourceUrl: "https://example.com/?utm_source=x", title: "重复测试" }),
       (error) => error.code === "DUPLICATE_BOOKMARK" && error.details.duplicate.id === itemId
    );
    assert.equal(created, undefined);

    const item = await itemService.create("7", {
      sourceUrl: "https://example.com/",
      title: "重复测试",
      allowDuplicate: true
    });
     assert.equal(item.id, itemId);
    assert.equal(created.userId, "7");
  } finally {
    itemModel.findDuplicate = originalDuplicate;
    itemModel.create = originalCreate;
  }
});

test("update rejects changing an item to another existing normalized URL", async () => {
  const originalFindDuplicate = itemModel.findDuplicate;
  const originalFindById = itemModel.findById;
  const originalUpdate = itemModel.update;
  itemModel.findById = async () => ({
    id: itemId,
    sourceUrl: "https://example.com/old",
    folderId: null,
    title: null,
    description: null,
    coverUrl: null
  });
  itemModel.findDuplicate = async () => ({
    id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    title: "existing",
    folderId: null,
    folderName: null
  });
  let updated = false;
  itemModel.update = async () => { updated = true; };
  try {
    await assert.rejects(
      itemService.update("7", itemId, { sourceUrl: "https://example.com/existing" }),
      (error) => error.code === "DUPLICATE_BOOKMARK"
    );
    assert.equal(updated, false);
  } finally {
    itemModel.findDuplicate = originalFindDuplicate;
    itemModel.findById = originalFindById;
    itemModel.update = originalUpdate;
  }
});

test("list supports uncategorized keyword search and stable pagination inputs", async () => {
  const originalList = itemModel.list;
  let received;
  itemModel.list = async (userId, filters) => {
    received = { userId, ...filters };
    return { items: [{ id: "3" }], total: 1 };
  };
  try {
    const result = await itemService.list("22", {
      uncategorized: "true",
      query: " example ",
      page: "2",
      pageSize: "10"
    });
    assert.deepEqual(received, {
    userId: "22",
    folderId: null,
    space: "star",
    includeDescendants: false,
    uncategorized: true,
      query: "example",
      page: 2,
      pageSize: 10
    });
    assert.deepEqual(result, { items: [{ id: "3" }], total: 1, page: 2, pageSize: 10 });
  } finally {
    itemModel.list = originalList;
  }
});

test("create rejects another user's folder without creating an item", async () => {
  const originalFindFolder = folderModel.findById;
  const originalCreate = itemModel.create;
  folderModel.findById = async () => null;
  let called = false;
  itemModel.create = async () => { called = true; };
  try {
    await assert.rejects(
       itemService.create("11111111111111111111111111111111", { folderId: folderId, sourceUrl: "https://example.com", title: "目录测试" }),
      (error) => error.code === "FOLDER_NOT_FOUND"
    );
    assert.equal(called, false);
  } finally {
    folderModel.findById = originalFindFolder;
    itemModel.create = originalCreate;
  }
});

test("create and update validate and expose coverUrl values", async () => {
  const originalDuplicate = itemModel.findDuplicate;
  const originalCreate = itemModel.create;
  itemModel.findDuplicate = async () => null;
   itemModel.create = async (userId, values) => ({ id: itemId, userId, ...values });
  try {
    const item = await itemService.create("7", {
      sourceUrl: "https://example.com/article",
      title: "封面测试",
      coverUrl: "https://cdn.example.com/cover image.jpg"
    });
    assert.equal(item.coverUrl, "https://cdn.example.com/cover%20image.jpg");
    await assert.rejects(
       itemService.create("7", { sourceUrl: "https://example.com", title: "封面测试", coverUrl: "file:///secret" }),
      (error) => error.code === "INVALID_URL" && error.status === 400
    );
  } finally {
    itemModel.findDuplicate = originalDuplicate;
    itemModel.create = originalCreate;
  }
});
