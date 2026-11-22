const express = require("express");
const authController = require("../controllers/auth.controller");
const auth = require("../middlewares/auth");

const router = express.Router();

router.post("/register", authController.register);
router.post("/login", authController.login);
router.post("/change-password", auth, authController.changePassword);
router.get("/profile", auth, authController.profile);
router.patch("/profile", auth, authController.updateProfile);
// 使用独立路径，兼容旧部署或反向代理对 profile 路径的特殊处理。
router.get("/user-profile", auth, authController.profile);
router.patch("/user-profile", auth, authController.updateProfile);

module.exports = router;
