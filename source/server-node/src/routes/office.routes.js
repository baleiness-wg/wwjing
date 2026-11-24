const express = require("express");
const officeAuth = require("../middlewares/office-auth");
const officeController = require("../controllers/office.controller");
const { createRateLimiter } = require("../office/write-limits");

const router = express.Router();
const allowWrite = createRateLimiter({ limit: 120, windowMs: 10000 });
function limitWrites(req, res, next) {
  // 不使用可伪造的游客昵称或转发头作为限流依据。
  if (allowWrite(req.socket.remoteAddress || "unknown")) return next();
  res.set("Retry-After", "10");
  return res.status(429).json({ message: "操作过于频繁，请稍后重试" });
}
router.use(...officeAuth);
router.get("/snapshot", officeController.snapshot);
router.post("/cell", limitWrites, officeController.updateCell);
router.post("/lock", limitWrites, officeController.updateLock);

module.exports = router;
