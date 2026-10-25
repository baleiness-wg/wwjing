const test = require("node:test");
const assert = require("node:assert/strict");
const folderService = require("../src/services/bookmark-folder.service");
const folderModel = require("../src/models/bookmark-folder.model");

function transactionDouble() {
  const queries = [];
  return {
    queries,
    async query(sql) { queries.push(sql); },
    release() {}
  };
}

test("create rejects a parent not owned by the authenticated user", async () => {
  const originalFind = folderModel.findById;
  const originalCreate = folderModel.create;
  folderModel.findById = async () => null;
  let called = false;
  folderModel.create = async () => { called = true; };
  try {
    await assert.rejects(
      folderService.create("1", { name: "child", parentId: "20" }),
      (error) => error.code === "FOLDER_NOT_FOUND"
    );
    assert.equal(called, false);
  } finally {
    folderModel.findById = originalFind;
    folderModel.create = originalCreate;
  }
});

test("moving a folder below its descendant rolls back without updating", async () => {
  const client = transactionDouble();
  const originals = {
    connect: folderModel.pool.connect,
    find: folderModel.findById,
    descendant: folderModel.isDescendant,
    update: folderModel.update
  };
  folderModel.pool.connect = async () => client;
  folderModel.findById = async (userId, id) => ({
    id, parentId: null, name: id === "1" ? "parent" : "child", position: 0, userId
  });
  folderModel.isDescendant = async () => true;
  let updated = false;
  folderModel.update = async () => { updated = true; };
  try {
    await assert.rejects(
      folderService.update("7", "1", { parentId: "2" }),
      (error) => error.code === "FOLDER_CYCLE"
    );
    assert.equal(updated, false);
    assert.deepEqual(client.queries, ["BEGIN", "ROLLBACK"]);
  } finally {
    folderModel.pool.connect = originals.connect;
    folderModel.findById = originals.find;
    folderModel.isDescendant = originals.descendant;
    folderModel.update = originals.update;
  }
});

test("deleting a non-empty folder is rejected and rolled back", async () => {
  const client = transactionDouble();
  const originals = {
    connect: folderModel.pool.connect,
    find: folderModel.findById,
    contents: folderModel.hasContents,
    remove: folderModel.remove
  };
  folderModel.pool.connect = async () => client;
  folderModel.findById = async () => ({ id: "5", name: "non-empty", position: 0 });
  folderModel.hasContents = async () => true;
  let removed = false;
  folderModel.remove = async () => { removed = true; };
  try {
    await assert.rejects(
      folderService.remove("7", "5"),
      (error) => error.code === "FOLDER_NOT_EMPTY"
    );
    assert.equal(removed, false);
    assert.deepEqual(client.queries, ["BEGIN", "ROLLBACK"]);
  } finally {
    folderModel.pool.connect = originals.connect;
    folderModel.findById = originals.find;
    folderModel.hasContents = originals.contents;
    folderModel.remove = originals.remove;
  }
});
