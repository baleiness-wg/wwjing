require("dotenv").config();

module.exports = {
  host: process.env.HOST || "0.0.0.0",
  port: Number(process.env.PORT) || 3000,
  jwtSecretKey: process.env.JWT_SECRET_KEY || "wwjing-development-secret",
  ai: {
    apiKey: process.env.AI_API_KEY || "",
    baseUrl: process.env.AI_BASE_URL || "",
    model: process.env.AI_MODEL || "",
    timeoutMs: Number(process.env.AI_TIMEOUT_MS) || 30000
  },
  database: {
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME || "postgres",
    user: process.env.DB_USER || "postgres",
    password: process.env.DB_PASSWORD || "123456"
  }
};
