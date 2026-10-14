const express = require("express");
const multer = require("multer");
const auth = require("../middlewares/auth");
const controller = require("../controllers/transfer.controller");

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: controller.maxFileSize }
});
const router = express.Router();

router.use(auth);
router.get("/content", controller.getContent);
router.post("/content/text", controller.saveText);
router.post("/content/file", upload.single("file"), controller.saveFile);
router.get("/content/file", controller.downloadFile);

module.exports = router;
