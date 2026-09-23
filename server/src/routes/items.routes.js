const express = require("express");
const itemsController = require("../controllers/items.controller");
const auth = require("../middlewares/auth");

const router = express.Router();

router.get("/", auth, itemsController.list);
router.post("/", auth, itemsController.create);

module.exports = router;
