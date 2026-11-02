const pool = require("../db")

const EXPENSE_CATEGORIES = [
  "Food", "Groceries", "Transport", "Shopping", "Bills", "Rent",
  "Entertainment", "Health", "Education", "Travel", "Subscriptions", "Other",
]
const INCOME_CATEGORIES = ["Salary", "Freelance", "Gift", "Refund", "Interest", "Top-up", "Other"]

function cleanCategory(type, category) {
  const list = type === "income" ? INCOME_CATEGORIES : EXPENSE_CATEGORIES
  const match = list.find((c) => c.toLowerCase() === String(category || "").trim().toLowerCase())
  return match || "Other"
}

// validates + normalises a transaction coming from the app, SMS sync or xp
function parseTransaction(body) {
  const type = body.type === "income" ? "income" : "expense"
  const amount = Math.round(Number(body.amount) * 100) / 100
  if (!Number.isFinite(amount) || amount <= 0 || amount > 100000000) {
    return { error: "Amount must be a positive number" }
  }
  const date = body.txn_date ? new Date(body.txn_date) : new Date()
  if (Number.isNaN(date.getTime())) return { error: "Invalid date" }

  return {
    value: {
      type,
      amount,
      category: cleanCategory(type, body.category),
      title: String(body.title || "").trim().slice(0, 120),
      note: body.note ? String(body.note).slice(0, 1000) : null,
      txn_date: date.toISOString(),
      source: ["manual", "sms", "xp"].includes(body.source) ? body.source : "manual",
      source_ref: body.source_ref ? String(body.source_ref).slice(0, 64) : null,
    },
  }
}

async function insertTransaction(userId, t) {
  const result = await pool.query(
    `INSERT INTO transactions (user_id, type, amount, category, title, note, txn_date, source, source_ref)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     ON CONFLICT (user_id, source_ref) WHERE source_ref IS NOT NULL DO NOTHING
     RETURNING *`,
    [userId, t.type, t.amount, t.category, t.title || t.category, t.note, t.txn_date, t.source, t.source_ref]
  )
  return result.rows[0] ? serialize(result.rows[0]) : null
}

async function getBalance(userId) {
  const r = await pool.query(
    `SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0)::float AS balance
     FROM transactions WHERE user_id = $1`,
    [userId]
  )
  return r.rows[0].balance
}

// group_by: none | category | day | month | weekday
// tzOffset: the phone's UTC offset in minutes, so "day" means the user's day
async function summarize(userId, { from, to, type = "expense", groupBy = "none", category, tzOffset = 0 }) {
  const params = [userId, type]
  let where = "user_id = $1 AND type = $2"
  if (from) {
    params.push(from)
    where += ` AND txn_date >= $${params.length}`
  }
  if (to) {
    params.push(to)
    where += ` AND txn_date < $${params.length}`
  }
  if (category) {
    params.push(category)
    where += ` AND LOWER(category) = LOWER($${params.length})`
  }
  if (groupBy === "none" || !groupBy) {
    const r = await pool.query(
      `SELECT COALESCE(SUM(amount), 0)::float AS total, COUNT(*)::int AS count FROM transactions WHERE ${where}`,
      params
    )
    return { total: r.rows[0].total, count: r.rows[0].count }
  }

  if (groupBy !== "category") params.push(Number(tzOffset) || 0)
  const local = `(txn_date AT TIME ZONE 'UTC' + make_interval(mins => $${params.length}::int))`
  const keyExpr = {
    category: "category",
    day: `to_char(${local}, 'YYYY-MM-DD')`,
    month: `to_char(${local}, 'YYYY-MM')`,
    weekday: `to_char(${local}, 'FMDay')`,
  }[groupBy]
  if (!keyExpr) throw new Error(`unknown group_by: ${groupBy}`)

  const r = await pool.query(
    `SELECT ${keyExpr} AS key, SUM(amount)::float AS total, COUNT(*)::int AS count
     FROM transactions WHERE ${where}
     GROUP BY key ORDER BY ${groupBy === "category" ? "total DESC" : "key"}`,
    params
  )
  const total = r.rows.reduce((s, x) => s + x.total, 0)
  return { total, groups: r.rows }
}

function serialize(row) {
  return {
    id: row.id,
    type: row.type,
    amount: Number(row.amount),
    category: row.category,
    title: row.title,
    note: row.note,
    txn_date: row.txn_date instanceof Date ? row.txn_date.toISOString() : row.txn_date,
    source: row.source,
    created_at: row.created_at instanceof Date ? row.created_at.toISOString() : row.created_at,
  }
}

module.exports = {
  EXPENSE_CATEGORIES,
  INCOME_CATEGORIES,
  parseTransaction,
  insertTransaction,
  getBalance,
  summarize,
  serialize,
}
