const express = require("express");
const auth = require("../middlewares/auth");
const controller = require("../controllers/office-room.controller");
const router = express.Router();
router.use(auth);
router.get("/", controller.list);
router.post("/", controller.create);
module.exports = router;
