const express = require("express");
const cors = require("cors");
const crypto = require("node:crypto");
const pinoHttp = require("pino-http");
const apiRoutes = require("./routes");
const notFound = require("./middlewares/not-found");
const errorHandler = require("./middlewares/error-handler");
const logger = require("./logger");

const app = express();

app.use(pinoHttp({
  logger,
  genReqId(req, res) {
    const requestId = req.headers["x-request-id"] || crypto.randomUUID();
    res.setHeader("x-request-id", requestId);
    return requestId;
  },
  serializers: {
    req(req) {
      return {
        id: req.id,
        method: req.method,
        url: new URL(req.url, "http://localhost").pathname
      };
    },
    res(res) {
      return { statusCode: res.statusCode };
    }
  }
}));

app.use(
  cors({
    origin: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);
app.use(express.json());

app.use("/api", apiRoutes);
app.use(notFound);
app.use(errorHandler);

module.exports = app;
