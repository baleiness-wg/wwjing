const dns = require("node:dns");

// Some production hosts resolve Agnes through IPv6 but do not have a working IPv6 route.
dns.setDefaultResultOrder("ipv4first");

const http = require("node:http");
const app = require("./src/app");
const { attachOfficeWebSocket } = require("./src/office/office-ws");
const config = require("./src/config");
const logger = require("./src/logger");

const server = http.createServer(app);
attachOfficeWebSocket(server);
server.listen(config.port, config.host, () => {
  logger.info({
    host: config.host,
    port: config.port,
    address: `http://${config.host}:${config.port}`
  }, "server started");
});
