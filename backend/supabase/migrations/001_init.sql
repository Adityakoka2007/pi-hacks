create extension if not exists "pgcrypto";

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text,
    check_in_time text default '20:00',
    preferred_intervention_style text default 'gentle',
    created_at timestamptz not null default now()
);

create table if not exists public.daily_health_summaries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    summary_date date not null,
    sleep_hours double precision not null,
    steps integer not null,
    resting_heart_rate double precision,
    heart_rate_variability double precision,
    created_at timestamptz not null default now(),
    unique(user_id, summary_date)
);

create table if not exists public.daily_schedule_summaries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    summary_date date not null,
    event_count integer not null,
    busy_hours double precision not null,
    back_to_back_count integer not null,
    late_night_events integer not null,
    created_at timestamptz not null default now(),
    unique(user_id, summary_date)
);

create table if not exists public.stress_check_ins (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    check_in_date date not null,
    stress_level integer not null check (stress_level between 1 and 5),
    energy_level integer not null check (energy_level between 1 and 5),
    caffeine_servings integer not null default 0,
    notes text,
    created_at timestamptz not null default now()
);

create table if not exists public.stress_predictions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    target_date date not null,
    risk_level text not null check (risk_level in ('low', 'medium', 'high')),
    score double precision not null,
    top_factors jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now()
);

create table if not exists public.recommendations (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    target_date date not null,
    title text not null,
    body text not null,
    rationale text not null,
    category text not null,
    created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.daily_health_summaries enable row level security;
alter table public.daily_schedule_summaries enable row level security;
alter table public.stress_check_ins enable row level security;
alter table public.stress_predictions enable row level security;
alter table public.recommendations enable row level security;

create policy "profiles_select_own"
on public.profiles
for select
using (auth.uid() = id);

create policy "profiles_insert_own"
on public.profiles
for insert
with check (auth.uid() = id);

create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id);

create policy "health_select_own"
on public.daily_health_summaries
for select
using (auth.uid() = user_id);

create policy "health_insert_own"
on public.daily_health_summaries
for insert
with check (auth.uid() = user_id);

create policy "health_update_own"
on public.daily_health_summaries
for update
using (auth.uid() = user_id);

create policy "schedule_select_own"
on public.daily_schedule_summaries
for select
using (auth.uid() = user_id);

create policy "schedule_insert_own"
on public.daily_schedule_summaries
for insert
with check (auth.uid() = user_id);

create policy "schedule_update_own"
on public.daily_schedule_summaries
for update
using (auth.uid() = user_id);

create policy "check_ins_select_own"
on public.stress_check_ins
for select
using (auth.uid() = user_id);

create policy "check_ins_insert_own"
on public.stress_check_ins
for insert
with check (auth.uid() = user_id);

create policy "check_ins_update_own"
on public.stress_check_ins
for update
using (auth.uid() = user_id);

create policy "predictions_select_own"
on public.stress_predictions
for select
using (auth.uid() = user_id);

create policy "predictions_insert_own"
on public.stress_predictions
for insert
with check (auth.uid() = user_id);

create policy "predictions_update_own"
on public.stress_predictions
for update
using (auth.uid() = user_id);

create policy "recommendations_select_own"
on public.recommendations
for select
using (auth.uid() = user_id);

create policy "recommendations_insert_own"
on public.recommendations
for insert
with check (auth.uid() = user_id);

create policy "recommendations_update_own"
on public.recommendations
for update
using (auth.uid() = user_id);
