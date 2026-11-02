if (require.main === module) require("dotenv").config()
const pool = require("./db")

// Each migration runs once, in order, inside a transaction.
// Migrations are additive: old tables/columns are kept so nothing is lost.
const migrations = [
  {
    name: "001_users_and_expenses",
    sql: `
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) NOT NULL,
        email VARCHAR(100) NOT NULL UNIQUE,
        password VARCHAR(100),
        balance DOUBLE PRECISION DEFAULT 0
      );
    `,
  },
  {
    name: "002_secure_users",
    sql: `
      ALTER TABLE users ALTER COLUMN password DROP NOT NULL;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS monthly_budget NUMERIC(12,2) NOT NULL DEFAULT 0;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    `,
  },
  {
    name: "003_transactions",
    sql: `
      CREATE TABLE IF NOT EXISTS transactions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type VARCHAR(10) NOT NULL CHECK (type IN ('expense', 'income')),
        amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
        category VARCHAR(40) NOT NULL DEFAULT 'Other',
        title VARCHAR(120) NOT NULL DEFAULT '',
        note TEXT,
        txn_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        source VARCHAR(10) NOT NULL DEFAULT 'manual',
        source_ref VARCHAR(64),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS transactions_user_date ON transactions (user_id, txn_date DESC);
      CREATE UNIQUE INDEX IF NOT EXISTS transactions_user_source_ref
        ON transactions (user_id, source_ref) WHERE source_ref IS NOT NULL;

      CREATE TABLE IF NOT EXISTS budgets (
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        category VARCHAR(40) NOT NULL,
        amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
        PRIMARY KEY (user_id, category)
      );
    `,
  },
  {
    // Copy the old "expenses" rows into "transactions" and turn the old stored
    // balance into an opening-balance income so the derived balance matches it.
    name: "004_import_legacy_expenses",
    sql: `
      DO $$
      BEGIN
        IF to_regclass('public.expenses') IS NOT NULL THEN
          INSERT INTO transactions (user_id, type, amount, category, title, txn_date, source)
          SELECT user_id, 'expense', amount,
                 CASE category
                   WHEN 'Grocery' THEN 'Groceries'
                   WHEN 'Commute' THEN 'Transport'
                   WHEN 'Bill' THEN 'Bills'
                   WHEN '' THEN 'Other'
                   ELSE COALESCE(category, 'Other')
                 END,
                 COALESCE(NULLIF(category, ''), 'Expense'),
                 COALESCE(expense_date, NOW()), 'manual'
          FROM expenses
          WHERE user_id IS NOT NULL AND amount > 0;
        END IF;

        INSERT INTO transactions (user_id, type, amount, category, title, txn_date, source)
        SELECT u.id, 'income',
               COALESCE(u.balance, 0) + COALESCE((SELECT SUM(t.amount) FROM transactions t
                                                  WHERE t.user_id = u.id AND t.type = 'expense'), 0),
               'Top-up', 'Opening balance',
               LEAST(u.created_at, COALESCE((SELECT MIN(t.txn_date) FROM transactions t WHERE t.user_id = u.id), u.created_at))
                 - INTERVAL '1 second',
               'manual'
        FROM users u
        WHERE COALESCE(u.balance, 0) + COALESCE((SELECT SUM(t.amount) FROM transactions t
                                                 WHERE t.user_id = u.id AND t.type = 'expense'), 0) > 0;
      END $$;
    `,
  },
  {
    // old app versions could store joined chip labels like "CommuteOther"
    name: "005_normalize_categories",
    sql: `
      UPDATE transactions SET category = 'Transport' WHERE type = 'expense' AND category ILIKE 'commute%';
      UPDATE transactions SET category = 'Other'
      WHERE type = 'expense' AND category NOT IN
        ('Food','Groceries','Transport','Shopping','Bills','Rent','Entertainment','Health','Education','Travel','Subscriptions','Other');
    `,
  },
]

async function migrate() {
  const client = await pool.connect()
  try {
    await client.query(
      "CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY, run_at TIMESTAMPTZ NOT NULL DEFAULT NOW())"
    )
    const done = new Set((await client.query("SELECT name FROM schema_migrations")).rows.map((r) => r.name))

    for (const m of migrations) {
      if (done.has(m.name)) continue
      await client.query("BEGIN")
      try {
        await client.query(m.sql)
        await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [m.name])
        await client.query("COMMIT")
        console.log(`migration applied: ${m.name}`)
      } catch (err) {
        await client.query("ROLLBACK")
        throw new Error(`migration ${m.name} failed: ${err.message}`)
      }
    }
  } finally {
    client.release()
  }
}

module.exports = migrate

if (require.main === module) {
  migrate()
    .then(() => pool.end())
    .catch((err) => {
      console.error(err)
      process.exit(1)
    })
}
