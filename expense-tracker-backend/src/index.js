import express from "express";
import cors from "cors";
import dotenv from "dotenv";
dotenv.config();

import authRoutes from "./routes/auth.js"; 

const app = express();
app.use(cors());
app.use(express.json());

//routes
app.get("/", (req, res) => {
  res.send("Expense Tracker Backend Running ✅");
});

app.use("/api/auth",authRoutes);

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`🚀 Server running on http://localhost:${PORT}`));

