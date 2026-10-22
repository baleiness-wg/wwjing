const authService = require("../services/auth.service");
const logger = require("../logger");

async function register(req, res, next) {
  try {
    const user = await authService.register(req.body);
    (req.log || logger).info({ userId: user.id }, "user registeredd");
    res.status(201).json({ user });
  } catch (error) {
    next(error);
  }
}

async function login(req, res, next) {
  try {
    const result = await authService.login(req.body);
    (req.log || logger).info({ userId: result.user.id }, "user logged in");
    res.json(result);
  } catch (error) {
    next(error);
  }
}

module.exports = { register, login };
