const express = require("express");
const auth = require("../middlewares/auth");
const officeController = require("../controllers/office.controller");

const router = express.Router();
router.use(auth);
router.get("/snapshot", officeController.snapshot);

module.exports = router;
