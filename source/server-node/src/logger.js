const pino = require("pino");

const isDevelopment = (process.env.NODE_ENV || "development") !== "production";
const serviceName = process.env.SERVICE_NAME || "wwjing-server";

const options = {
  level: process.env.LOG_LEVEL || (isDevelopment ? "debug" : "info"),
  base: {
    service: serviceName,
    environment: process.env.NODE_ENV || "development"
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: {
    paths: [
      "req.headers.authorization",
      "req.headers.cookie",
      "req.body.password",
      "req.body.token",
      "req.body.text",
      "req.body.file",
      "req.body.description",
      "description",
      "password",
      "token",
      "accessToken",
      "refreshToken",
      "authorization"
    ],
    censor: "[REDACTED]"
  }
};

if (isDevelopment) {
  options.transport = {
    target: "pino-pretty",
    options: {
      colorize: true,
      translateTime: "SYS:standard",
      ignore: "pid,hostname"
    }
  };
}

module.exports = pino(options);
