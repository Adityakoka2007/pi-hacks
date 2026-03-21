-- Migration 002 — add structured factor breakdown to stress_predictions
-- Run in Supabase SQL editor after 001_init.sql.
--
-- Previously top_factors stored plain strings ("Sleep was 5h below baseline").
-- factor_scores stores numeric per-factor contributions so the iOS app can
-- render a breakdown chart without re-computing anything client-side.
--
-- factor_scores shape (all fields present even if raw value was unavailable):
-- {
--   "sleep":      { "raw_hours": 5.5, "score": 2.3, "max": 2.85, "weight": 0.356 },
--   "hrv":        { "raw_ms": 38,     "score": 1.4, "max": 2.13, "weight": 0.267, "available": true },
--   "activity":   { "raw_steps": 4200,"score": 0.9, "max": 1.69, "weight": 0.211 },
--   "resting_hr": { "raw_bpm": 74,    "score": 0.6, "max": 1.33, "weight": 0.167, "available": true },
--   "schedule":   { "score": 0.8, "max": 1.50, "busy_hours": 6, "back_to_back": 2, "late_night": 1 },
--   "check_in":   { "score": 0.3, "max": 0.50, "avg_stress": 3.2, "available": true }
-- }

alter table public.stress_predictions
  add column if not exists factor_scores jsonb not null default '{}'::jsonb;
