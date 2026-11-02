const jwt = require("jsonwebtoken")

const JWT_SECRET = process.env.JWT_SECRET

function signToken(user) {
  return jwt.sign({ sub: user.id }, JWT_SECRET, { expiresIn: "60d" })
}

//checks "Authorization: Bearer <token>" and puts the user id on req.userId
function requireAuth(req, res, next) {
  const header = req.headers.authorization || ""
  const token = header.startsWith("Bearer ") ? header.slice(7) : null
  if (!token) return res.status(401).json({ error: "Not signed in" })

  try {
    const payload = jwt.verify(token, JWT_SECRET)
    req.userId = Number(payload.sub)
    next()
  } catch {
    res.status(401).json({ error: "Session expired, please sign in again" })
  }
}

module.exports = { signToken, requireAuth }
