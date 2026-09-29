const express = require("express");
const healthRoutes = require("./health.routes");
const itemRoutes = require("./items.routes");
const authRoutes = require("./auth.routes");
const folderRoutes = require("./folders.routes");

const router = express.Router();

router.use("/health", healthRoutes);
router.use("/auth", authRoutes);
router.use("/items", itemRoutes);
router.use("/folders", folderRoutes);

module.exports = router;
