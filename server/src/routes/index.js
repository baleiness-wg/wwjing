const express = require("express");
const healthRoutes = require("./health.routes");
const favoriteDetailRoutes = require("./favorite-details.routes");
const authRoutes = require("./auth.routes");
const folderRoutes = require("./folders.routes");

const router = express.Router();

router.use("/health", healthRoutes);
router.use("/auth", authRoutes);
router.use("/favorite-details", favoriteDetailRoutes);
router.use("/folders", folderRoutes);

module.exports = router;
