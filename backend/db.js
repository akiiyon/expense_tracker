const { Pool } = require("pg")

//CONNECT TO POSTGRES (values come from .env, see .env.example)
const pool = new Pool(
  process.env.DATABASE_URL
    ? {
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
      }
    : {
        user: process.env.DB_USER || "postgres",
        host: process.env.DB_HOST || "localhost",
        database: process.env.DB_NAME || "expense_tracker_db",
        password: process.env.DB_PASSWORD,
        port: Number(process.env.DB_PORT || 5432),
      }
)

module.exports = pool
