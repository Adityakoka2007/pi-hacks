# Supabase Setup

## 1. Create The Project

Create a new project in Supabase and keep these values handy:

- project URL
- anon key

## 2. Run The Schema

Open the SQL editor and run:

- [backend/supabase/migrations/001_init.sql](/Users/ronit/Documents/hackathon/backend/supabase/migrations/001_init.sql)

## 3. Install The Swift Client

In Xcode, add the package:

- `https://github.com/supabase/supabase-swift`

## 4. Wire App Config (iOS)

The iOS app **does not read** `backend/supabase/.env`. Use one of:

1. **Xcode scheme:** Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables — add `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
2. **Bundled plist:** Copy `ios/MindMarginApp/SupabaseSecrets.example.plist` to `ios/MindMarginApp/SupabaseSecrets.plist`, fill in real values (`SupabaseSecrets.plist` is gitignored).

In Supabase: **Authentication → Providers** — enable **Anonymous** (for automatic sign-in on launch) and/or **Email** (for account sign-up).

## 5. Recommended Hackathon Auth

Use one of these:

- Anonymous auth for fastest demo onboarding (must be enabled in the Supabase dashboard).
- Email/password (enable the Email provider in Supabase).

## 6. First App Writes

Start by syncing only:

- `daily_health_summaries`
- `daily_schedule_summaries`
- `stress_check_ins`

You can generate predictions and recommendations locally first, then persist them later if you want history.
