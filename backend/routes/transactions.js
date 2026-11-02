const express = require("express")
const pool = require("../db")
const { requireAuth } = require("../middleware/auth")
const { parseTransaction, insertTransaction, getBalance, serialize } = require("../lib/finance")

const router = express.Router()
router.use(requireAuth)

//list transactions, newest first. optional ?from=&to=&type=&category=&limit=
router.get("/", async (req, res) => {
  const params = [req.userId]
  let where = "user_id = $1"
  const add = (clause, value) => {
    params.push(value)
    where += ` AND ${clause.replace("?", `$${params.length}`)}`
  }
  if (req.query.from) add("txn_date >= ?", req.query.from)
  if (req.query.to) add("txn_date < ?", req.query.to)
  if (req.query.type) add("type = ?", req.query.type)
  if (req.query.category) add("category = ?", req.query.category)
  const limit = Math.min(Number(req.query.limit) || 5000, 10000)

  try {
    const result = await pool.query(
      `SELECT * FROM transactions WHERE ${where} ORDER BY txn_date DESC, id DESC LIMIT ${limit}`,
      params
    )
    res.json({ transactions: result.rows.map(serialize), balance: await getBalance(req.userId) })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Could not load transactions" })
  }
})

//add a transaction (expense or income)
router.post("/", async (req, res) => {
  const parsed = parseTransaction(req.body)
  if (parsed.error) return res.status(400).json({ error: parsed.error })

  try {
    const txn = await insertTransaction(req.userId, parsed.value)
    if (!txn) return res.status(409).json({ error: "This transaction was already added" })
    res.status(201).json({ transaction: txn, balance: await getBalance(req.userId) })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Could not save transaction" })
  }
})

//add many at once (SMS sync). duplicates (same source_ref) are skipped
router.post("/batch", async (req, res) => {
  const items = Array.isArray(req.body.transactions) ? req.body.transactions.slice(0, 500) : []
  const added = []
  try {
    for (const item of items) {
      const parsed = parseTransaction(item)
      if (parsed.error) continue
      const txn = await insertTransaction(req.userId, parsed.value)
      if (txn) added.push(txn)
    }
    res.status(201).json({ added, balance: await getBalance(req.userId) })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Could not save transactions" })
  }
})

//edit a transaction
router.put("/:id", async (req, res) => {
  const parsed = parseTransaction(req.body)
  if (parsed.error) return res.status(400).json({ error: parsed.error })
  const t = parsed.value

  try {
    const result = await pool.query(
      `UPDATE transactions SET type = $3, amount = $4, category = $5, title = $6, note = $7, txn_date = $8
       WHERE id = $1 AND user_id = $2 RETURNING *`,
      [req.params.id, req.userId, t.type, t.amount, t.category, t.title || t.category, t.note, t.txn_date]
    )
    if (!result.rows[0]) return res.status(404).json({ error: "Transaction not found" })
    res.json({ transaction: serialize(result.rows[0]), balance: await getBalance(req.userId) })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Could not update transaction" })
  }
})

//delete a transaction
router.delete("/:id", async (req, res) => {
  try {
    const result = await pool.query("DELETE FROM transactions WHERE id = $1 AND user_id = $2", [
      req.params.id,
      req.userId,
    ])
    if (result.rowCount === 0) return res.status(404).json({ error: "Transaction not found" })
    res.json({ balance: await getBalance(req.userId) })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: "Could not delete transaction" })
  }
})

module.exports = router
