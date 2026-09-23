const app = require("./src/app");
const config = require("./src/config");

app.listen(config.port, () => {
  console.log(`WWJ server is running at http://localhost:${config.port}`);
});
