-- supabase/migrations/20260315000003_add_push_trigger.sql
--
-- Prerequisites:
--   - pg_net extension must be enabled (Dashboard → Database → Extensions → pg_net)
--   - Run once in SQL Editor (not this file) to set the project ref:
--       ALTER DATABASE postgres SET app.edge_function_base_url = 'https://<PROJECT-REF>.supabase.co/functions/v1';

CREATE OR REPLACE FUNCTION trigger_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url     := current_setting('app.edge_function_base_url') || '/send-push-notification',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body    := to_jsonb(NEW)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS push_on_notification_insert ON notifications;

CREATE TRIGGER push_on_notification_insert
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION trigger_push_notification();
