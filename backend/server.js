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
      "SELECT * FROM users WHERE email = $1",
      [email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ error: "Email already registered" });
    }

    // 2. Insert new user if not exists
    const result = await pool.query(
      "INSERT INTO users (username, email, password) VALUES ($1, $2, $3) RETURNING *",
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

    res.status(201).json({message: "New expense added!",expense: response.rows[0]})
  } catch (error) {
    res.status(500).json({error: error.message});
  }
})


app.listen(4000,()=>{
    console.log("server running on localhost:4000")
})