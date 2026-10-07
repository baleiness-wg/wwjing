const express = require("express");
const foldersController = require("../controllers/folders.controller");
const auth = require("../middlewares/auth");

const router = express.Router();
router.get("/", auth, foldersController.list);
router.post("/", auth, foldersController.create);

module.exports = router;
