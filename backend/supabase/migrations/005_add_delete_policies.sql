-- Allow analyze-stress to replace prior rows for the same user/date.

drop policy if exists "predictions_delete_own" on public.stress_predictions;
create policy "predictions_delete_own"
on public.stress_predictions
for delete
using (auth.uid() = user_id);

drop policy if exists "recommendations_delete_own" on public.recommendations;
create policy "recommendations_delete_own"
on public.recommendations
for delete
using (auth.uid() = user_id);
