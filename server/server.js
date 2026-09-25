const app = require("./src/app");
const config = require("./src/config");

app.listen(config.port, config.host, () => {
  console.log(`WWJ server is running at http://${config.host}:${config.port}`);
});
