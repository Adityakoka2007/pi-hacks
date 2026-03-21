# Architecture

## Goals

- Keep the core experience functional on-device
- Minimize sensitive data sent to the server
- Separate raw platform integrations from domain logic
- Make it easy to start with heuristics and later swap in ML
- Use managed backend primitives so the team can ship quickly

## System Overview

```text
HealthKit + EventKit + Daily Check-ins
                |
                v
        Feature Engineering
                |
                v
      Stress Prediction Service
                |
                v
    Recommendation Generation Layer
                |
                v
      SwiftUI Dashboard + Insights
                |
                v
  Supabase Auth + Postgres + RLS + Storage
```

## iOS Layers

### Features

- `Onboarding`
- `Dashboard`
- `CheckIn`
- `Insights`
- `Settings`

### Domain

- `Models`: pure app data structures
- `Services`: protocols for predictions, recommendations, and sync
- `UseCases`: orchestration logic

### Platform

- `HealthKit`: raw Apple Health access
- `Calendar`: `EventKit` integration
- `Persistence`: local caching via `SwiftData`
- `Networking`: `Supabase` client

## Supabase Responsibilities

- `Auth`: email magic link, Apple, or anonymous auth
- `Postgres`: profiles, summaries, check-ins, predictions, recommendations
- `RLS`: user-scoped access to sensitive data
- `Storage`: optional exports or generated reports
- `Edge Functions`: optional recommendation generation or remote model endpoints

## Initial Prediction Approach

Start with a rule-based predictor:

- poor sleep relative to baseline
- low recent activity
- elevated resting heart rate trend
- dense calendar tomorrow
- recent high stress self-reports

This makes the output explainable for a hackathon demo. Later, you can replace the implementation behind the `StressPredicting` protocol with a Core ML or remote model.

## Privacy Model

- All data collection is opt-in
- Predictions can run fully on-device
- Only daily summaries and check-ins need to be synced
- Delete/export paths should be supported from day one
- Recommendations must be framed as supportive, not diagnostic
- Row-level security should restrict all per-user tables
