require("dotenv").config();

module.exports = {
  port: Number(process.env.PORT) || 3000,
  jwtSecretKey: process.env.JWT_SECRET_KEY || "wwjing-development-secret",
  database: {
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME || "postgres",
    user: process.env.DB_USER || "postgres",
    password: process.env.DB_PASSWORD || "123456"
  }
};
