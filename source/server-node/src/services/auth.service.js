const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const config = require("../config");
const usersModel = require("../models/users.model");

async function register({ username, password }) {
  validateCredentials(username, password);

  const existingUser = await usersModel.findByUsername(username);
  if (existingUser) {
    const error = new Error("用户名已存在");
    error.status = 409;
    throw error;
  }

  const passwordHash = await bcrypt.hash(password, 10);
  return usersModel.create({ username, passwordHash });
}

async function login({ username, password }) {
  validateCredentials(username, password);

  const user = await usersModel.findByUsername(username);
  const passwordMatches = user && await bcrypt.compare(password, user.passwordHash);

  if (!passwordMatches) {
    const error = new Error("用户名或密码错误");
    error.status = 401;
    throw error;
  }

  const token = jwt.sign(
    { sub: String(user.id), username: user.username },
    config.jwtSecretKey,
    { expiresIn: "7d" }
  );

  return { user, token: `Bearer ${token}` };
}

async function changePassword(userId, { currentPassword, newPassword, confirmPassword }) {
  if (!currentPassword || !newPassword || !confirmPassword) {
    const error = new Error("当前密码、新密码和确认密码不能为空");
    error.status = 400;
    throw error;
  }
  if (newPassword !== confirmPassword) {
    const error = new Error("两次输入的新密码不一致");
    error.status = 400;
    throw error;
  }
  const user = await usersModel.findById(userId);
  if (!user || !(await bcrypt.compare(currentPassword, user.passwordHash))) {
    const error = new Error("当前密码错误");
    error.status = 401;
    throw error;
  }
  await usersModel.updatePassword(userId, await bcrypt.hash(newPassword, 10));
}

function validateCredentials(username, password) {
  if (!username || !password) {
    const error = new Error("用户名和密码不能为空");
    error.status = 400;
    throw error;
  }
}

module.exports = { register, login, changePassword };
