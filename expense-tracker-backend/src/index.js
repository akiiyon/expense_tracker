import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { PrismaClient } from '@prisma/client'



dotenv.config();
const app = express();
const prisma = new PrismaClient();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("Expense Tracker Backend Running ✅");
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`🚀 Server running on http://localhost:${PORT}`));

//auth inserted
import authRoutes from "./routes/auth.js";
app.use("/auth", authRoutes);
//CRUD
import expenseRoutes from "./routes/expenses.js";
app.use("/expenses", expenseRoutes);
