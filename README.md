# pi-hacks (MindMargin)

MindMargin is a privacy-first student wellness app that uses `HealthKit`, calendar load, and daily check-ins to estimate short-term stress risk and surface actionable recommendations before burnout escalates.

## Repository Layout

```text
apps/
  ios/StudentStressCoach/     SwiftUI starter structure
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

The iOS app source layout is initialized under [apps/ios/StudentStressCoach](apps/ios/StudentStressCoach). This environment does not have full Xcode available, so the Xcode project/target was not generated here.

To finish setup locally:

1. Create a new iOS App project named `MindMargin`
2. Replace the generated source groups with the files from [apps/ios/StudentStressCoach](apps/ios/StudentStressCoach)
3. Install the Supabase Swift client with Swift Package Manager:
   - `https://github.com/supabase/supabase-swift`
4. Add capabilities:
   - `HealthKit`
   - `Background Modes`
5. Add usage descriptions in `Info.plist`
6. Fill your Supabase config in the app environment

## MVP Architecture

- `SwiftUI` app owns permissions, feature generation, prediction, recommendations, and local caching
- `Supabase` owns auth, sync, row-level security, and persistent history
- Daily aggregates are synced instead of raw high-frequency health streams

See [docs/architecture.md](docs/architecture.md) for the full system design.
