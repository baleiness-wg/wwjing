const express = require("express");
const controller = require("../controllers/favorite-details.controller");
const auth = require("../middlewares/auth");

const router = express.Router();

router.get("/", auth, controller.list);
router.post("/", auth, controller.create);

module.exports = router;
