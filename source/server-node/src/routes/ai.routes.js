const express = require("express");
const auth = require("../middlewares/auth");
const controller = require("../controllers/ai.controller");

const router = express.Router();

router.use(auth);
router.post("/chat", controller.chat);

module.exports = router;
