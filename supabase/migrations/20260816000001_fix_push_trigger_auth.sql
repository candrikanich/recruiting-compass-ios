-- Fix: the push trigger (20260315000003_add_push_trigger.sql) posted to the
-- send-push-notification edge function WITHOUT an Authorization header, but that
-- function has verify_jwt=true. Every push was rejected with 401 Invalid JWT and
-- nothing was ever delivered. Add the (public) anon key as a Bearer token so the
-- request clears the gateway. The function uses its own SERVICE_ROLE_KEY env
-- internally, so caller privilege does not matter — anon is sufficient and safe
-- to embed (it already ships in the iOS binary).

CREATE OR REPLACE FUNCTION public.trigger_push_notification()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
  BEGIN
    PERFORM net.http_post(
      url     := 'https://xpxzhqghxecsjhvklsqg.supabase.co/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhweHpocWdoeGVjc2podmtsc3FnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3NzI1ODQsImV4cCI6MjA4MDM0ODU4NH0.WNlq1neCdjY-hDCvJRLplntd9w2HKqahwpHa7rB_Zro'
      ),
      body    := to_jsonb(NEW)
    );
    RETURN NEW;
  END;
  $function$;
