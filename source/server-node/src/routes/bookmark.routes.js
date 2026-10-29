const express = require("express");
const auth = require("../middlewares/auth");
const folderController = require("../controllers/bookmark-folder.controller");
const itemController = require("../controllers/bookmark-item.controller");
const metadataController = require("../controllers/bookmark-metadata.controller");
const tagController = require("../controllers/bookmark-tag.controller");
const randomController = require("../controllers/bookmark-random.controller");

const router = express.Router();

router.use(auth);
router.post("/metadata", metadataController.fetchMetadata);
router.get("/folders", folderController.list);
router.post("/folders", folderController.create);
router.patch("/folders/:id", folderController.update);
router.delete("/folders/:id", folderController.remove);
router.get("/items", itemController.list);
router.post("/items", itemController.create);
router.get("/items/:id", itemController.get);
router.patch("/items/:id", itemController.update);
router.delete("/items/:id", itemController.remove);
router.get("/tags", tagController.list);
router.post("/tags", tagController.create);
router.patch("/tags/:id", tagController.update);
router.delete("/tags/:id", tagController.remove);
router.get("/random", randomController.random);

module.exports = router;
