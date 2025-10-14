const express=require("express")
const bodyParser=require("body-parser")
const cors=require("cors")
//adding postgres
const {Pool}=require("pg")

const app=express()

app.use(bodyParser.json())
app.use(cors())

//CONNECT TO POSTGRES
const pool = new Pool({
  user: "postgres",     //postgres username
  host: "localhost",
  database: "expense_tracker_db",   //DB name
  password: "7854",
  port: 3000,     //postgres PORT -> default is 5432,i used 3000
})

//default route
app.get("/",(req,res)=>{
    console.log("here")

    //**for sending user files to download**
    // -->res.download("server.js")


    res.status(200).json({name:"akii",message: "you will make it soon"})
})

//signup route
app.post("/signup",async (req,res)=>{
    const{username,email,password}=req.body

    try {
    // 1. Check if email already exists
    const existingUser = await pool.query(
      "SELECT id, username, email, balance FROM users WHERE email = $1",
      [email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ error: "Email already registered" });
    }

    // 2. Insert new user if not exists
    const result = await pool.query(
      "INSERT INTO users (username, email, password) VALUES ($1, $2, $3) RETURNING id, username, email, balance",
      [username, email, password]
    );

    res.status(201).json({ message:"New user signedup!",user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
})

//signin route
app.post("/signin",async (req,res)=>{
    const{email,password}=req.body

    try {
    // 1. Check if user exists
    const user = await pool.query(
      "SELECT * FROM users WHERE email = $1 AND password =$2",
      [email,password]
    );

    if (user.rows.length == 0) {
      return res.status(400).json({ error: "Invalid email or password" });
    }

    // 2. if found,send user back
    

    res.status(201).json({ message:"User logged in",user: user.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
})

//add expense
app.post('/addExpense',async (req,res)=>{
  const{user_id, amount, category, expense_date}=req.body

  try {
    const response=await pool.query(
      "INSERT INTO expenses (user_id, amount, category, expense_date) VALUES ($1, $2, $3, $4) RETURNING*",
      [user_id,amount,category,expense_date]

    )

    //also update user's balance in user table by subtracting the expense
    const walltetBalance=await pool.query(
      "UPDATE users SET balance = balance -$1 WHERE id =$2 RETURNING balance",
      [amount,user_id]
    )

    res.status(201).json({message: "New expense added! & balance updated",expense: response.rows[0],balance:walltetBalance.rows[0].balance})
  } catch (error) {
    res.status(500).json({error: error.message});
  }
})

//add money to wallet (update user's balance)

app.post('/credit',async (req,res)=>{
  const {user_id,balance}=req.body

  try {
    const response =await pool.query(
    "UPDATE users SET balance = balance + $2 WHERE id = $1 RETURNING *",
    [user_id,balance]
  )

  if(response.rows.length==0){
    return res.status(404).json({ error: "User not found" })
  }
  res.status(200).json({
      message: "Balance credited successfully",
      user: response.rows[0],
    });
  } catch (error) {
    console.error("Error crediting balance:", error);
    res.status(500).json({ error: "Internal server error" });
  }
})

//get past week expenses
app.get("/expenses/week/:user_id",async (req,res)=>{
  const{user_id}=req.params;

  try {
    const result = await pool.query(
      "SELECT category, SUM(amount) :: float AS total FROM expenses WHERE user_id =$1 AND expense_date>=NOW() - INTERVAL '7 days' GROUP BY category ORDER BY category",
      [user_id]
    )

    res.status(200).json(result.rows)
  } catch (error) {
    res.status(500).json({error: error.message})
  }
})



app.listen(4000,()=>{
    console.log("server running on localhost:4000")
})