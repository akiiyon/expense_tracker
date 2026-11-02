require("dotenv").config()

const express = require("express")
const cors = require("cors")
const migrate = require("./migrate")

if (!process.env.JWT_SECRET) {
  console.error("JWT_SECRET is missing. Copy .env.example to .env and fill it in.")
  process.exit(1)
}

const app = express()

app.use(express.json({ limit: "1mb" }))
app.use(cors())

//health check (used by hosting providers)
app.get("/", (req, res) => {
  res.status(200).json({ name: "expensify-api", status: "ok" })
})

app.use("/auth", require("./routes/auth"))
app.use("/transactions", require("./routes/transactions"))
app.use("/budgets", require("./routes/budgets"))
app.use("/xp", require("./routes/xp"))

const PORT = Number(process.env.PORT || 4000)

migrate()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`server running on port ${PORT}`)
    })
  })
  .catch((err) => {
    console.error("could not start:", err)
    process.exit(1)
  })
