const express = require("express")
const rateLimit = require("express-rate-limit")
const Anthropic = require("@anthropic-ai/sdk")
const pool = require("../db")
const { requireAuth } = require("../middleware/auth")
const {
  EXPENSE_CATEGORIES,
  INCOME_CATEGORIES,
  parseTransaction,
  insertTransaction,
  getBalance,
  summarize,
  serialize,
} = require("../lib/finance")

const router = express.Router()
router.use(requireAuth)
router.use(rateLimit({ windowMs: 60 * 1000, limit: 20, keyGenerator: (req) => String(req.userId) }))

const MODEL = process.env.XP_MODEL || "claude-opus-5-5"
const client = process.env.ANTHROPIC_API_KEY ? new Anthropic() : null

// Kept byte-for-byte stable so it can be prompt-cached; per-request facts go in the user turn.
const SYSTEM_PROMPT = `You are xp, the AI money companion inside an expense-tracker app used mostly in India (currency: Indian Rupee, write amounts like ₹1,250).

Personality: warm, upbeat and a little witty, like a smart best friend who happens to be great with money. You're encouraging, never preachy or judgy, and you celebrate small wins. You may tease gently ("okay, that's a lot of chai") but you're always on the user's side. Use at most one emoji per reply, and often none.

Your replies are shown in a chat bubble and are often read aloud by a voice, so:
- Keep it short: 1-4 sentences, or a short list of at most 5 lines when breaking numbers down.
- Plain text only. No markdown headings, tables, bold or code.
- Lead with the answer (the number), then one useful observation.

What you can do with tools:
- Add expenses or income for the user. If the user clearly states an amount and what it was for, add it right away and confirm briefly; pick the closest category yourself. Only ask a follow-up question if the amount is missing.
- Look up spending for any period, grouped by category, day, month or weekday.
- List individual transactions.
- Check the wallet balance.
- Spot patterns (e.g. weekends vs weekdays, spikes right after salary days, favourite categories) and suggest specific, realistic ways to cut unnecessary spending. Base advice on the user's real numbers from the tools, not generic tips.

Rules:
- Always use tools for numbers; never invent amounts or transactions.
- Resolve relative dates ("yesterday", "last month", "this weekend") using the current local date-time given with each message. Date ranges are [from, to): "to" is exclusive.
- Only talk about personal finance, budgeting and this app. For anything else, steer back politely in one sentence.
- You are not a licensed financial advisor: for investment or tax questions, give general education only and suggest a professional for specific advice.`

const tools = [
  {
    name: "add_transaction",
    description:
      "Record a new expense or income for the user. Use when the user says they spent, paid, bought, received or got money.",
    input_schema: {
      type: "object",
      properties: {
        type: { type: "string", enum: ["expense", "income"] },
        amount: { type: "number", description: "Amount in rupees, positive" },
        category: {
          type: "string",
          enum: [...new Set([...EXPENSE_CATEGORIES, ...INCOME_CATEGORIES])],
          description: `Expense categories: ${EXPENSE_CATEGORIES.join(", ")}. Income categories: ${INCOME_CATEGORIES.join(", ")}.`,
        },
        title: { type: "string", description: "Short label, e.g. 'Pizza with friends' or 'Uber to office'" },
        date: { type: "string", description: "ISO 8601 date-time with offset. Omit for now." },
      },
      required: ["type", "amount", "category", "title"],
    },
  },
  {
    name: "get_summary",
    description:
      "Total spending (or income) in a period, optionally grouped by category, day, month or weekday. Use for 'how much did I spend', breakdowns, comparisons and pattern finding.",
    input_schema: {
      type: "object",
      properties: {
        from: { type: "string", description: "ISO date-time, inclusive. Omit for all time." },
        to: { type: "string", description: "ISO date-time, exclusive. Omit for up to now." },
        type: { type: "string", enum: ["expense", "income"], description: "Default expense" },
        group_by: { type: "string", enum: ["none", "category", "day", "month", "weekday"] },
        category: { type: "string", description: "Only this category" },
      },
      required: ["group_by"],
    },
  },
  {
    name: "list_transactions",
    description: "List individual transactions, newest first.",
    input_schema: {
      type: "object",
      properties: {
        from: { type: "string" },
        to: { type: "string" },
        type: { type: "string", enum: ["expense", "income"] },
        category: { type: "string" },
        limit: { type: "integer", description: "Max rows, default 20, max 50" },
      },
    },
  },
  {
    name: "get_balance",
    description: "Current wallet balance (all income minus all expenses) and this month's budget.",
    input_schema: { type: "object", properties: {} },
  },
]

async function runTool(name, input, ctx) {
  switch (name) {
    case "add_transaction": {
      const parsed = parseTransaction({
        type: input.type,
        amount: input.amount,
        category: input.category,
        title: input.title,
        txn_date: input.date,
        source: "xp",
      })
      if (parsed.error) return { error: parsed.error }
      const txn = await insertTransaction(ctx.userId, parsed.value)
      ctx.added.push(txn)
      return { added: txn, balance: await getBalance(ctx.userId) }
    }
    case "get_summary":
      return summarize(ctx.userId, {
        from: input.from,
        to: input.to,
        type: input.type || "expense",
        groupBy: input.group_by || "none",
        category: input.category,
        tzOffset: ctx.tzOffset,
      })
    case "list_transactions": {
      const params = [ctx.userId]
      let where = "user_id = $1"
      for (const [col, op, value] of [
        ["txn_date", ">=", input.from],
        ["txn_date", "<", input.to],
        ["type", "=", input.type],
        ["category", "=", input.category],
      ]) {
        if (!value) continue
        params.push(value)
        where += ` AND ${col} ${op} $${params.length}`
      }
      const limit = Math.min(Math.max(Number(input.limit) || 20, 1), 50)
      const r = await pool.query(
        `SELECT * FROM transactions WHERE ${where} ORDER BY txn_date DESC LIMIT ${limit}`,
        params
      )
      return { transactions: r.rows.map(serialize).map(({ id, created_at, ...t }) => t) }
    }
    case "get_balance": {
      const r = await pool.query("SELECT monthly_budget::float AS b FROM users WHERE id = $1", [ctx.userId])
      return { balance: await getBalance(ctx.userId), monthly_budget: r.rows[0]?.b || 0 }
    }
    default:
      return { error: `Unknown tool ${name}` }
  }
}

// history from the app: [{ role: "user" | "xp", text }]. Must alternate and start with the user.
function buildMessages(history, message, contextLine) {
  const messages = []
  for (const turn of (Array.isArray(history) ? history : []).slice(-12)) {
    const role = turn.role === "user" ? "user" : "assistant"
    const text = String(turn.text || "").slice(0, 2000)
    if (!text) continue
    if (messages.length === 0 && role !== "user") continue
    const last = messages[messages.length - 1]
    if (last && last.role === role) last.content += `\n${text}`
    else messages.push({ role, content: text })
  }
  if (messages.length && messages[messages.length - 1].role === "user") messages.pop()
  messages.push({ role: "user", content: `${contextLine}\n\n${String(message).slice(0, 2000)}` })
  return messages
}

router.post("/chat", async (req, res) => {
  if (!client) return res.status(503).json({ error: "xp cloud brain is not configured on the server" })
  const message = String(req.body.message || "").trim()
  if (!message) return res.status(400).json({ error: "Empty message" })

  const tzOffset = Number(req.body.tz_offset) || 0
  const now = String(req.body.now || new Date().toISOString())
  const userRow = await pool.query("SELECT username FROM users WHERE id = $1", [req.userId])
  const contextLine = `[Context] User's name: ${userRow.rows[0]?.username || "friend"}. Current local date-time: ${now} (UTC offset ${tzOffset} min).`

  const ctx = { userId: req.userId, tzOffset, added: [] }
  const messages = buildMessages(req.body.history, message, contextLine)

  try {
    let reply = ""
    for (let step = 0; step < 6; step++) {
      const response = await client.beta.messages.create({
        model: MODEL,
        max_tokens: 4000,
        system: [{ type: "text", text: SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }],
        output_config: { effort: "low" },
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        tools,
        messages,
      })

      if (response.stop_reason === "refusal") {
        reply = "Hmm, I can't help with that one. Ask me anything about your spending though!"
        break
      }

      const text = response.content
        .filter((b) => b.type === "text")
        .map((b) => b.text)
        .join("")
        .trim()
      if (text) reply = text

      if (response.stop_reason === "pause_turn") {
        messages.push({ role: "assistant", content: response.content })
        continue
      }
      if (response.stop_reason !== "tool_use") break

      messages.push({ role: "assistant", content: response.content })
      const results = []
      for (const block of response.content.filter((b) => b.type === "tool_use")) {
        let result
        try {
          result = await runTool(block.name, block.input || {}, ctx)
        } catch (err) {
          console.error(`xp tool ${block.name} failed:`, err)
          result = { error: "Tool failed" }
        }
        results.push({
          type: "tool_result",
          tool_use_id: block.id,
          content: JSON.stringify(result),
          ...(result && result.error ? { is_error: true } : {}),
        })
      }
      messages.push({ role: "user", content: results })
    }

    res.json({
      reply: reply || "Done!",
      mutated: ctx.added.length > 0,
      added: ctx.added.filter(Boolean),
    })
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) {
      return res.status(429).json({ error: "xp is a bit busy, try again in a moment" })
    }
    if (err instanceof Anthropic.APIError) {
      console.error(`xp API error ${err.status}:`, err.message)
      return res.status(502).json({ error: "xp's cloud brain is unavailable right now" })
    }
    console.error("xp chat failed:", err)
    res.status(500).json({ error: "xp ran into a problem" })
  }
})

module.exports = router
