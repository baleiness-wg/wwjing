const dns = require("node:dns");

// Some production hosts resolve Agnes through IPv6 but do not have a working IPv6 route.
dns.setDefaultResultOrder("ipv4first");

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
