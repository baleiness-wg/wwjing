const express = require("express");
const officeAuth = require("../middlewares/office-auth");
const officeController = require("../controllers/office.controller");

const router = express.Router();
router.use(...officeAuth);
router.get("/snapshot", officeController.snapshot);
router.post("/cell", officeController.updateCell);

module.exports = router;
