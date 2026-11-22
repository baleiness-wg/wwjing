const express = require("express");
const authController = require("../controllers/auth.controller");
const auth = require("../middlewares/auth");

const router = express.Router();

router.post("/register", authController.register);
router.post("/login", authController.login);
router.post("/change-password", auth, authController.changePassword);
router.get("/profile", auth, authController.profile);
router.patch("/profile", auth, authController.updateProfile);

module.exports = router;
