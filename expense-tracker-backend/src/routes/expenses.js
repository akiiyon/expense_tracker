import express from "express";
import jwt from "jsonwebtoken";
import { PrismaClient } from "@prisma/client";

const router = express.Router();
const prisma = new PrismaClient();

// Middleware to check token
function authenticateToken(req, res, next) {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];
  if (!token) return res.sendStatus(401);

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.userId = user.userId;
    next();
  });
}

// Get all expenses
router.get("/", authenticateToken, async (req, res) => {
  const expenses = await prisma.expense.findMany({
    where: { userId: req.userId },
  });
  res.json(expenses);
});

// Add expense
router.post("/", authenticateToken, async (req, res) => {
  const { title, amount, category, date, note } = req.body;
  const expense = await prisma.expense.create({
    data: { title, amount, category, date: new Date(date), note, userId: req.userId },
  });
  res.json(expense);
});

// Update expense
router.put("/:id", authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { title, amount, category, date, note } = req.body;
  const expense = await prisma.expense.update({
    where: { id: parseInt(id) },
    data: { title, amount, category, date: new Date(date), note },
  });
  res.json(expense);
});

// Delete expense
router.delete("/:id", authenticateToken, async (req, res) => {
  const { id } = req.params;
  await prisma.expense.delete({ where: { id: parseInt(id) } });
  res.json({ message: "Deleted" });
});

export default router;
