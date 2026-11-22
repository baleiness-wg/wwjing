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

async function changePassword(req, res, next) {
  try {
    await authService.changePassword(req.auth.sub, req.body);
    (req.log || logger).info({ userId: req.auth.sub }, "user changed password");
    res.json({ message: "密码修改成功" });
  } catch (error) {
    next(error);
  }
}

async function profile(req, res, next) {
  try {
    const user = await require("../models/users.model").findById(req.auth.sub);
    if (!user) return res.status(404).json({ error: { code: "USER_NOT_FOUND", message: "用户不存在" } });
    res.json({ user });
  } catch (error) { next(error); }
}

async function updateProfile(req, res, next) {
  try {
    const description = typeof req.body.description === "string" ? req.body.description.trim().slice(0, 4000) : "";
    const user = await require("../models/users.model").updateProfileDescription(req.auth.sub, description);
    if (!user) return res.status(404).json({ error: { code: "USER_NOT_FOUND", message: "用户不存在" } });
    res.json({ user });
  } catch (error) { next(error); }
}

module.exports = { register, login, changePassword, profile, updateProfile };
