# Cron Schedules

Registered via pg_cron in Supabase SQL Editor.

| Job | Schedule (UTC) | ET equivalent | SQL |
|---|---|---|---|
| process-follow-up-reminders | 0 12 * * * | 8am ET daily | See below |
| process-deadline-alerts | 0 12 * * * | 8am ET daily | See below |
| send-weekly-digest | 0 12 * * 1 | 8am ET Monday | See below |

## Registration SQL (run once in Supabase SQL Editor)

```sql
SELECT cron.schedule(
  'process-follow-up-reminders',
  '0 12 * * *',
  $$SELECT net.http_post(
      url := 'https://<PROJECT-REF>.supabase.co/functions/v1/process-follow-up-reminders',
      headers := '{"Authorization":"Bearer <SUPABASE_ANON_KEY>"}'::jsonb
  )$$
);

SELECT cron.schedule(
  'process-deadline-alerts',
  '0 12 * * *',
  $$SELECT net.http_post(
      url := 'https://<PROJECT-REF>.supabase.co/functions/v1/process-deadline-alerts',
      headers := '{"Authorization":"Bearer <SUPABASE_ANON_KEY>"}'::jsonb
  )$$
);

SELECT cron.schedule(
  'send-weekly-digest',
  '0 12 * * 1',
  $$SELECT net.http_post(
      url := 'https://<PROJECT-REF>.supabase.co/functions/v1/send-weekly-digest',
      headers := '{"Authorization":"Bearer <SUPABASE_ANON_KEY>"}'::jsonb
  )$$
);
```
