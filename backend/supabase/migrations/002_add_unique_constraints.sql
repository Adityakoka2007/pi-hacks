-- Allow upsert behavior on stress_predictions by enforcing one prediction per user per day
alter table public.stress_predictions
    add constraint stress_predictions_user_date_unique
    unique (user_id, target_date);
