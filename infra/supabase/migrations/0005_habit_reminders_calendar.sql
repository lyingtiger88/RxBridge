-- Add configurable local reminder times to physician-authored habit plans.
alter table public.habit_plans
  add column if not exists reminder_times text[] not null default '{}';
alter table public.habit_plans
  add constraint habit_plans_reminder_times_valid
  check (
    cardinality(reminder_times) <= 8
    and reminder_times <@ array(
      select to_char(make_time(h,m,0),'HH24:MI')
      from generate_series(0,23) h cross join generate_series(0,59) m
    )
  );
