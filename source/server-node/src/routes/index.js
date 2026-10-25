const express = require("express");
const healthRoutes = require("./health.routes");
const authRoutes = require("./auth.routes");
const transferRoutes = require("./transfer.routes");
const bookmarkRoutes = require("./bookmark.routes");

const router = express.Router();

router.use("/health", healthRoutes);
router.use("/auth", authRoutes);
router.use("/transfer", transferRoutes);
router.use("/bookmarks", bookmarkRoutes);

module.exports = router;
