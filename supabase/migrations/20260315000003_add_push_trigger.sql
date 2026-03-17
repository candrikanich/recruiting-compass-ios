-- supabase/migrations/20260315000003_add_push_trigger.sql
--
-- Prerequisites:
--   - pg_net extension must be enabled (Dashboard → Database → Extensions → pg_net)
--   - Replace <PROJECT-REF> below with your Supabase project ref before running

CREATE OR REPLACE FUNCTION trigger_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://<PROJECT-REF>.supabase.co/functions/v1/send-push-notification',
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
