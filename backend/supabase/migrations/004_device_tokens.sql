-- Migration 003 — device tokens + database webhook
-- Run in Supabase SQL editor after 002_add_factor_scores.sql.
--
-- This migration does two things:
--   1. Creates the device_tokens table so the iOS app can register its APNs
--      token. The edge function reads from this table to know where to send
--      push notifications.
--   2. Documents the Database Webhook you must configure in the Supabase
--      dashboard to trigger the edge function automatically when new health
--      data arrives.

-- ── 1. device_tokens ──────────────────────────────────────────────────────────
-- One row per user per device. A user can have multiple devices.
-- The token is the raw APNs device token (hex string, 64 chars).
-- updated_at is refreshed on every upsert so stale tokens can be pruned.

create table if not exists public.device_tokens (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references auth.users(id) on delete cascade,
    token      text not null,
    updated_at timestamptz not null default now(),
    unique(user_id, token)
);

alter table public.device_tokens enable row level security;

-- Users can only read and write their own tokens.
create policy "device_tokens_select_own"
    on public.device_tokens for select
    using (auth.uid() = user_id);

create policy "device_tokens_insert_own"
    on public.device_tokens for insert
    with check (auth.uid() = user_id);

create policy "device_tokens_update_own"
    on public.device_tokens for update
    using (auth.uid() = user_id);

create policy "device_tokens_delete_own"
    on public.device_tokens for delete
    using (auth.uid() = user_id);

-- The edge function reads device tokens using the service role key (bypasses
-- RLS) so no service-role policy is needed here.


-- ── 2. Database Webhook — configure in the Supabase dashboard ─────────────────
--
-- SQL cannot configure database webhooks directly. Follow these steps once
-- in the Supabase dashboard after running this migration:
--
-- Dashboard → Database → Webhooks → Create a new webhook
--
--   Name:       trigger-stress-on-health-insert
--   Table:      public.daily_health_summaries
--   Events:     INSERT
--   Type:       HTTP Request
--   URL:        https://<your-project-ref>.supabase.co/functions/v1/stress-analysis
--   Method:     POST
--   Headers:
--     Content-Type:   application/json
--     Authorization:  Bearer <your-service-role-key>   ← from Settings → API
--
-- The webhook sends the new row as JSON:
--   {
--     "type": "INSERT",
--     "table": "daily_health_summaries",
--     "record": { "user_id": "...", "summary_date": "...", ... },
--     "old_record": null
--   }
--
-- The edge function detects this shape (presence of "type" and "record")
-- and switches to service-role mode, using record.user_id and
-- record.summary_date as the target user and date.
--
-- Result: every time the iOS app writes new health data to
-- daily_health_summaries (which it already does via SupabaseService),
-- the edge function runs automatically, calculates the new stress score,
-- and sends an APNs push notification if the score spiked — without the
-- app needing to be open.


-- ── 3. Edge function environment variables ────────────────────────────────────
--
-- Add these to Supabase → Settings → Edge Functions → Secrets:
--
--   APNS_KEY_ID      10-character key ID from Apple Developer portal
--                    (Keys → your APNs auth key)
--   APNS_TEAM_ID     10-character team ID from Apple Developer portal
--                    (Membership → Team ID)
--   APNS_PRIVATE_KEY Full content of the .p8 auth key file, including the
--                    -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY-----
--                    lines, with literal \n between lines (not actual newlines).
--                    Example value in the Supabase secret field:
--                    -----BEGIN PRIVATE KEY-----\nMIGTA...\n-----END PRIVATE KEY-----
--   APNS_BUNDLE_ID   Your app's bundle ID, e.g. com.yourcompany.mindmargin
--   APNS_SANDBOX     "true" during development, "false" (or omit) for production
