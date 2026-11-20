const express = require("express");
const officeAuth = require("../middlewares/office-auth");
const controller = require("../controllers/office-room.controller");
const router = express.Router();
router.use(...officeAuth);
router.get("/", controller.list);
router.post("/", controller.create);
module.exports = router;
