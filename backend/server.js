const express=require("express")
const bodyParser=require("body-parser")
const cors=require("cors")

const app=express()

app.use(bodyParser.json())
app.use(cors())


//temporary users
let users=[]


//default route
app.get("/",(req,res)=>{
    console.log("here")

    //**for sending user files to download**
    // -->res.download("server.js")


    res.status(200).json({name:"akii",message: "you will make it soon"})
})

//signup route
app.post("/signup",(req,res)=>{
    const{username,email,password}=req.body

    //check if email already exists
  const existingUser = users.find((user) => user.email === email);
  if (existingUser) {
    return res.status(400).json({ message: "Email already registered" });
  }

  //add new user 
  const newUser={username,email,password}
  users.push(newUser)
  res.status(201).json({message: "User created successfully",user:newUser})
})


app.listen(4000,()=>{
    console.log("server running on localhost:4000")
})