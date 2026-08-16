-- Fix + extend the notification cron jobs.
--
-- BUG: the three existing cron commands (process-follow-up-reminders,
-- process-deadline-alerts, send-weekly-digest) carried the LITERAL, never-
-- substituted string '<SUPABASE_ANON_KEY>' in their Authorization header, so
-- every invocation was rejected 401 Invalid JWT and no scheduled notification
-- was ever produced. Re-schedule all jobs by name (cron.schedule upserts) with
-- the real public anon key, and add the daily event-reminder job.
--
-- The anon key below is the project's public anon key (also embedded in the iOS
-- app); it only needs to clear verify_jwt at the gateway.

SELECT cron.schedule(
  'process-follow-up-reminders', '0 12 * * *',
  $cmd$SELECT net.http_post(
      url := 'https://xpxzhqghxecsjhvklsqg.supabase.co/functions/v1/process-follow-up-reminders',
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhweHpocWdoeGVjc2podmtsc3FnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3NzI1ODQsImV4cCI6MjA4MDM0ODU4NH0.WNlq1neCdjY-hDCvJRLplntd9w2HKqahwpHa7rB_Zro')
  )$cmd$
);

SELECT cron.schedule(
  'process-deadline-alerts', '0 12 * * *',
  $cmd$SELECT net.http_post(
      url := 'https://xpxzhqghxecsjhvklsqg.supabase.co/functions/v1/process-deadline-alerts',
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhweHpocWdoeGVjc2podmtsc3FnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3NzI1ODQsImV4cCI6MjA4MDM0ODU4NH0.WNlq1neCdjY-hDCvJRLplntd9w2HKqahwpHa7rB_Zro')
  )$cmd$
);

SELECT cron.schedule(
  'send-weekly-digest', '0 12 * * 1',
  $cmd$SELECT net.http_post(
      url := 'https://xpxzhqghxecsjhvklsqg.supabase.co/functions/v1/send-weekly-digest',
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhweHpocWdoeGVjc2podmtsc3FnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3NzI1ODQsImV4cCI6MjA4MDM0ODU4NH0.WNlq1neCdjY-hDCvJRLplntd9w2HKqahwpHa7rB_Zro')
  )$cmd$
);

-- New: daily event reminder (24h before start_date). Runs the in-DB function
-- from 20260816000002 directly; no edge function or auth header needed.
SELECT cron.schedule(
  'notify-upcoming-events', '0 12 * * *',
  $cmd$SELECT public.notify_upcoming_events()$cmd$
);
