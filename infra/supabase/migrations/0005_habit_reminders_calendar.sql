-- Add configurable local reminder times to physician-authored habit plans.
alter table public.habit_plans
  add column if not exists reminder_times text[] not null default '{}';
alter table public.habit_plans
  add constraint habit_plans_reminder_times_valid
  check (
    cardinality(reminder_times) <= 8
    and (
      cardinality(reminder_times) = 0
      or array_to_string(reminder_times, ',') ~ '^([01][0-9]|2[0-3]):[0-5][0-9](,([01][0-9]|2[0-3]):[0-5][0-9])*$'
    )
  );
