const app = require("./src/app");
const config = require("./src/config");
const logger = require("./src/logger");

app.listen(config.port, config.host, () => {
  logger.info({
    host: config.host,
    port: config.port,
    address: `http://${config.host}:${config.port}`
  }, "server started");
});
