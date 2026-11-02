const express = require("express")
const pool = require("../db")
const { requireAuth } = require("../middleware/auth")
const { EXPENSE_CATEGORIES } = require("../lib/finance")

const router = express.Router()
router.use(requireAuth)

//category budgets: { budgets: { Food: 5000, ... } }
router.get("/", async (req, res) => {
  try {
    const result = await pool.query("SELECT category, amount::float AS amount FROM budgets WHERE user_id = $1", [
      req.userId,
    ])
    res.json({ budgets: Object.fromEntries(result.rows.map((r) => [r.category, r.amount])) })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Could not load budgets" })
  }
})

//set one category budget. amount 0 removes it
router.put("/:category", async (req, res) => {
  const category = EXPENSE_CATEGORIES.find((c) => c === req.params.category)
  const amount = Number(req.body.amount)
  if (!category) return res.status(400).json({ error: "Unknown category" })
  if (!Number.isFinite(amount) || amount < 0) return res.status(400).json({ error: "Invalid amount" })

  try {
    if (amount === 0) {
      await pool.query("DELETE FROM budgets WHERE user_id = $1 AND category = $2", [req.userId, category])
    } else {
      await pool.query(
        `INSERT INTO budgets (user_id, category, amount) VALUES ($1, $2, $3)
         ON CONFLICT (user_id, category) DO UPDATE SET amount = EXCLUDED.amount`,
        [req.userId, category, amount]
      )
    }
    res.json({ category, amount })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Could not save budget" })
  }
})

module.exports = router
