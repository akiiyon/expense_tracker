const express = require("express")
const bcrypt = require("bcryptjs")
const rateLimit = require("express-rate-limit")
const pool = require("../db")
const { signToken, requireAuth } = require("../middleware/auth")
const { getBalance } = require("../lib/finance")

const router = express.Router()

// slow down password guessing
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 30, standardHeaders: true, legacyHeaders: false })

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

async function publicUser(row) {
  return {
    id: row.id,
    username: row.username,
    email: row.email,
    monthly_budget: Number(row.monthly_budget || 0),
    balance: await getBalance(row.id),
  }
}

//signup route
router.post("/signup", authLimiter, async (req, res) => {
  const username = String(req.body.username || "").trim()
  const email = String(req.body.email || "").trim().toLowerCase()
  const password = String(req.body.password || "")

  if (username.length < 2) return res.status(400).json({ error: "Please enter your name" })
  if (!EMAIL_RE.test(email)) return res.status(400).json({ error: "Please enter a valid email" })
  if (password.length < 6) return res.status(400).json({ error: "Password must be at least 6 characters" })

  try {
    // 1. Check if email already exists
    const existing = await pool.query("SELECT id FROM users WHERE LOWER(email) = $1", [email])
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: "This email is already registered" })
    }

    // 2. Insert new user with a hashed password
    const hash = await bcrypt.hash(password, 10)
    const result = await pool.query(
      "INSERT INTO users (username, email, password_hash, balance) VALUES ($1, $2, $3, 0) RETURNING *",
      [username.slice(0, 50), email, hash]
    )
    const user = result.rows[0]
    res.status(201).json({ token: signToken(user), user: await publicUser(user) })
  } catch (err) {
    console.error("signup failed:", err)
    res.status(500).json({ error: "Could not create account, try again" })
  }
})

//signin route
router.post("/signin", authLimiter, async (req, res) => {
  const email = String(req.body.email || "").trim().toLowerCase()
  const password = String(req.body.password || "")

  try {
    const result = await pool.query("SELECT * FROM users WHERE LOWER(email) = $1", [email])
    const user = result.rows[0]

    let ok = false
    if (user && user.password_hash) {
      ok = await bcrypt.compare(password, user.password_hash)
    } else if (user && user.password && user.password === password) {
      // account from before hashing: upgrade it now and drop the plain-text copy
      ok = true
      const hash = await bcrypt.hash(password, 10)
      await pool.query("UPDATE users SET password_hash = $1, password = NULL WHERE id = $2", [hash, user.id])
    }

    if (!ok) return res.status(401).json({ error: "Invalid email or password" })
    res.status(200).json({ token: signToken(user), user: await publicUser(user) })
  } catch (err) {
    console.error("signin failed:", err)
    res.status(500).json({ error: "Could not sign in, try again" })
  }
})

//current user (used on app start to restore the session)
router.get("/me", requireAuth, async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM users WHERE id = $1", [req.userId])
    if (!result.rows[0]) return res.status(404).json({ error: "User not found" })
    res.json({ user: await publicUser(result.rows[0]) })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Internal server error" })
  }
})

//update profile: name and monthly budget
router.patch("/me", requireAuth, async (req, res) => {
  const { username, monthly_budget } = req.body
  try {
    const result = await pool.query(
      `UPDATE users SET
         username = COALESCE($2, username),
         monthly_budget = COALESCE($3, monthly_budget)
       WHERE id = $1 RETURNING *`,
      [
        req.userId,
        username ? String(username).trim().slice(0, 50) : null,
        monthly_budget != null && Number(monthly_budget) >= 0 ? Number(monthly_budget) : null,
      ]
    )
    res.json({ user: await publicUser(result.rows[0]) })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Internal server error" })
  }
})

//delete account and all data (required by both app stores)
router.delete("/me", requireAuth, async (req, res) => {
  try {
    await pool.query("DELETE FROM users WHERE id = $1", [req.userId])
    res.status(204).end()
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Internal server error" })
  }
})

module.exports = router
