# pi-hacks (MindMargin)

MindMargin is a privacy-first student wellness app that uses `HealthKit`, calendar load, and daily check-ins to estimate short-term stress risk and surface actionable recommendations before burnout escalates.

## Repository Layout

```text
ios/
  MindMarginApp/              Active iOS app source used by the Xcode project
backend/
  supabase/                   Supabase schema, policies, and setup files
docs/                         Architecture and product notes
```

## Product Scope

- Read opt-in sleep, activity, and recovery data from `HealthKit`
- Read schedule density signals from `EventKit`
- Collect lightweight user check-ins
- Produce explainable stress-risk predictions
- Sync summaries and preferences with `Supabase`
- Provide structured, non-diagnostic recommendations

## Quick Start

### Supabase Backend

1. Create a Supabase project
2. In the Supabase SQL editor, run [backend/supabase/migrations/001_init.sql](backend/supabase/migrations/001_init.sql)
3. Copy [backend/supabase/.env.example](backend/supabase/.env.example) to your local config and fill in your project URL and anon key
4. Use [backend/README.md](backend/README.md) for the table and RLS setup flow

### iOS App

The active iOS app source lives under [ios/MindMarginApp](/Users/adityakoka/Desktop/my-projects/pi%20hacks%20hackathon%20proj/ios/MindMarginApp) and is already connected to the checked-in Xcode project at [pi hacks.xcodeproj](/Users/adityakoka/Desktop/my-projects/pi%20hacks%20hackathon%20proj/pi%20hacks.xcodeproj).

To finish setup locally:

1. Open [pi hacks.xcodeproj](/Users/adityakoka/Desktop/my-projects/pi%20hacks%20hackathon%20proj/pi%20hacks.xcodeproj)
2. Add your `SUPABASE_URL` and `SUPABASE_ANON_KEY` values in the app environment or `Info.plist`
3. Add capabilities if needed:
   - `HealthKit`
   - `Background Modes`
4. Add any required usage descriptions in `Info.plist`

## MVP Architecture

- `SwiftUI` app owns permissions, feature generation, prediction, recommendations, and local caching
- `Supabase` owns auth, sync, row-level security, and persistent history
- Daily aggregates are synced instead of raw high-frequency health streams

See [docs/architecture.md](docs/architecture.md) for the full system design.
