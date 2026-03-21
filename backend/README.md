# Supabase Backend Setup

This project uses Supabase instead of a custom backend server.

## What Lives Here

- `supabase/migrations/001_init.sql`: database schema and row-level security policies
- `supabase/.env.example`: app-side environment variables to mirror in local config

## Setup Flow

1. Create a new Supabase project
2. Open the SQL editor
3. Run [supabase/migrations/001_init.sql](/Users/ronit/Documents/hackathon/backend/supabase/migrations/001_init.sql)
4. Copy your project URL and anon key into your iOS app config

## Recommended Auth Modes

- `Sign in with Apple` for the real app
- anonymous auth for demo-mode onboarding if you want a faster hackathon flow

## Core Tables

- `profiles`
- `daily_health_summaries`
- `daily_schedule_summaries`
- `stress_check_ins`
- `stress_predictions`
- `recommendations`

## Security Notes

- Each table uses row-level security
- Users can only read and write their own rows
- Health and schedule data should be stored as daily summaries, not raw event streams
