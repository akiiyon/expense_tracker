// src/config/db.js
import pkg from "pg";
import dotenv from "dotenv";

dotenv.config();

const { Pool } = pkg;

// Create a new PostgreSQL connection pool
const pool = new Pool({
  user: process.env.DB_USER,     // e.g. expense_user
  host: process.env.DB_HOST,     // usually localhost
  database: process.env.DB_NAME, // e.g. expense_tracker
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,     // e.g. 5432
});

export default pool;

pool.connect()
  .then(client => {
    console.log("✅ Connected to PostgreSQL");
    client.release();
  })
  .catch(err => console.error("❌ DB connection error:", err.stack));
