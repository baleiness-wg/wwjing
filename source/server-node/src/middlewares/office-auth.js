const { expressjwt } = require("express-jwt");
const config = require("../config");

module.exports = [
  expressjwt({ secret: config.jwtSecretKey, algorithms: ["HS256"], credentialsRequired: false }),
  (req, res, next) => {
    if (!req.auth) {
      const name = String(req.headers["x-office-guest"] || "游客").trim().slice(0, 40);
      req.auth = { sub: `guest:${name}`, username: name || "游客" };
    }
    next();
  }
];
