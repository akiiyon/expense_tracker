# Expensify (working name)

A personal expense tracker for India with **xp**, a built-in AI money buddy you can type or talk to, and automatic transaction detection from bank / UPI SMS.

> Before publishing, read [STORE_READINESS.md](STORE_READINESS.md). The name, SMS permissions and backend hosting all need attention.

## Features
- Expenses and income across 12 expense and 7 income categories, plus wallet balance, monthly budget and per-category budgets.
- **Home**: animated balance card, budget ring, today vs your usual, last 7 days, and a nudge from xp.
- **Activity**: month by month, search, filters, swipe to delete with undo, tap to edit.
- **Insights**: week / month / year views, tap-to-drill donut, interactive bars with an average line, 6-month spend vs earn trend, pattern cards and budget progress.
- **xp** (`lib/xp/`):
  - Add entries by text or voice ("spent 250 on pizza yesterday", "got salary 50000").
  - Answer questions for any day, range, month or category, with day / month / category / weekday breakdowns and comparison to the previous period.
  - Spot patterns (weekend splurges, payday spikes, rising categories, small frequent spends, late-night buys, subscriptions, budget pace) and suggest specific savings.
  - Feminine voice, warm and witty personality. Works offline on-device, with the backend's Claude-powered cloud brain as a fallback.
- **SMS detection** (Android, `lib/sms/` + `android/.../SmsReceiver.kt`): reads bank, card and UPI SMS, ignores OTPs, promos and failed or pending payments, skips duplicates by reference number, and either adds payments automatically or queues them for review. When an SMS doesn't say what a payment was for (e.g. a UPI transfer to a person), xp asks: a sheet pops up in the app, or, if the app is closed, the notification asks "what was it for?" with an inline reply and quick category buttons. Payments from the first-time 30-day backfill aren't asked about.
- Animated logo splash, light and dark themes, haptics.

## Run it locally

### Backend
```
cd backend
copy .env.example .env      # fill in DB_* and JWT_SECRET (and ANTHROPIC_API_KEY for xp's cloud brain)
npm install
npm run devStart
```
Migrations run automatically on start. They're additive: the old `expenses` table is copied into `transactions` and kept.

### App
```
flutter pub get
flutter run
```
The Android emulator reaches the backend at `http://10.0.2.2:4000` automatically. On a real phone, pass your PC's LAN IP:
`flutter run --dart-define=API_URL=http://192.168.x.x:4000` (and add that IP to `network_security_config.xml` for HTTP).

### Tests
```
flutter test
```
Covers xp's language understanding, date parsing, pattern detection, the SMS parser (real-world bank formats) and an app smoke test.

## Layout
```
lib/
  core/       theme, categories, formatting, config
  data/       models + API client
  state/      session, finance, settings providers
  analytics/  totals, breakdowns, pattern detection, saving tips
  xp/         engine (NLU), date parser, voice, chat controller
  sms/        SMS parser + sync service
  screens/    splash, auth, home, activity, insights, profile, xp, SMS review
  widgets/    logo, xp orb, transaction tile, add sheet, shared bits
backend/
  routes/     auth, transactions, budgets, xp (Claude tool use)
  lib/        finance helpers shared by routes and xp tools
  migrate.js  versioned migrations
```
