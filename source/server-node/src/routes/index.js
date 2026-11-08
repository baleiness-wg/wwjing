const express = require("express");
const healthRoutes = require("./health.routes");
const authRoutes = require("./auth.routes");
const transferRoutes = require("./transfer.routes");
const bookmarkRoutes = require("./bookmark.routes");
const aiRoutes = require("./ai.routes");

const router = express.Router();

router.use("/health", healthRoutes);
router.use("/auth", authRoutes);
router.use("/transfer", transferRoutes);
router.use("/bookmarks", bookmarkRoutes);
router.use("/ai", aiRoutes);

module.exports = router;
