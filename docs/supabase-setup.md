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

## 4. Wire App Config

Provide `SUPABASE_URL` and `SUPABASE_ANON_KEY` to the app target used by [ios/MindMarginApp](/Users/adityakoka/Desktop/my-projects/pi%20hacks%20hackathon%20proj/ios/MindMarginApp), either through the environment or `Info.plist`.

## 5. Recommended Hackathon Auth

Use one of these:

- anonymous auth for fastest demo onboarding
- Sign in with Apple for the polished version

## 6. First App Writes

Start by syncing only:

- `daily_health_summaries`
- `daily_schedule_summaries`
- `stress_check_ins`

You can generate predictions and recommendations locally first, then persist them later if you want history.
