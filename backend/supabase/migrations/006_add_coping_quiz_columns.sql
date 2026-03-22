alter table public.profiles
  add column if not exists preferred_coping_strategies text[] default '{}',
  add column if not exists avoided_coping_strategies text[] default '{}',
  add column if not exists stress_triggers text[] default '{}',
  add column if not exists support_style text,
  add column if not exists preferred_reset_length text;
