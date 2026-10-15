const pino = require("pino");

const isDevelopment = (process.env.NODE_ENV || "development") !== "production";
const serviceName = process.env.SERVICE_NAME || "wwjing-server";
const environment = process.env.NODE_ENV || "development";

const loggerOptions = {
  level: process.env.LOG_LEVEL || (isDevelopment ? "debug" : "info"),
  base: {
    service: serviceName,
    environment
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: {
    paths: [
      "req.headers.authorization",
      "req.headers.cookie",
      "req.body.password",
      "req.body.token",
      "req.body.accessToken",
      "password",
      "token",
      "accessToken",
      "jwt",
      "database.password",
      "databasePassword",
      "secret"
    ],
    censor: "[REDACTED]"
  }
};

if (isDevelopment) {
  loggerOptions.transport = {
    target: "pino-pretty",
    options: {
      colorize: true,
      translateTime: "SYS:standard",
      ignore: "pid,hostname"
    }
  };
}

module.exports = pino(loggerOptions);
