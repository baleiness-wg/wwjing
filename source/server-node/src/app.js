const express = require("express");
const cors = require("cors");
const crypto = require("node:crypto");
const apiRoutes = require("./routes");
const notFound = require("./middlewares/not-found");
const errorHandler = require("./middlewares/error-handler");
const logger = require("./logger");
const pinoHttp = require("pino-http");

const app = express();

app.use(
  pinoHttp({
    logger,
    genReqId: (req, res) => {
      const requestId = crypto.randomUUID();
      res.setHeader("X-Request-Id", requestId);
      return requestId;
    },
    customLogLevel: (req, res, error) => {
      if (error || res.statusCode >= 500) return "error";
      if (res.statusCode >= 400) return "warn";
      return "info";
    },
    serializers: {
      req: (req) => ({
        id: req.id,
        method: req.method,
        url: req.originalUrl || req.url,
        remoteAddress: req.socket?.remoteAddress
      }),
      res: (res) => ({ statusCode: res.statusCode })
    }
  })
);

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
