-- Event-driven notifications: offer, inbound interaction, event.
-- Each inserts into notifications; the push_on_notification_insert trigger
-- delivers via APNs. Recipients = all members of the row's family_unit
-- (family-shared), falling back to the owning user_id when there is no family.

-- 1. OFFER: notify the whole family when a new offer is logged.
CREATE OR REPLACE FUNCTION public.notify_on_offer()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  school_name text;
  recipients  uuid[];
BEGIN
  SELECT name INTO school_name FROM schools WHERE id = NEW.school_id;

  SELECT COALESCE(array_agg(fm.user_id), ARRAY[NEW.user_id])
    INTO recipients
  FROM family_members fm
  WHERE fm.family_unit_id = NEW.family_unit_id;

  INSERT INTO notifications (user_id, type, title, message,
                            related_entity_type, related_entity_id, priority)
  SELECT uid, 'offer', 'New offer 🎉',
         'New ' || COALESCE(NEW.offer_type, 'scholarship') || ' offer'
           || COALESCE(' from ' || school_name, '') || '.',
         'offer', NEW.id, 'high'
  FROM unnest(recipients) AS uid
  WHERE uid IS NOT NULL;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_on_offer_insert ON public.offers;
CREATE TRIGGER notify_on_offer_insert
  AFTER INSERT ON public.offers
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_offer();

-- 2. INBOUND INTERACTION: notify the REST of the family (not the logger) when a
--    coach-initiated interaction is recorded. Solo users get nothing (self-
--    notifying about a row you just typed is pointless).
CREATE OR REPLACE FUNCTION public.notify_on_inbound_interaction()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  coach_name text;
BEGIN
  IF NEW.family_unit_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT trim(COALESCE(first_name, '') || ' ' || COALESCE(last_name, ''))
    INTO coach_name
  FROM coaches WHERE id = NEW.coach_id;

  INSERT INTO notifications (user_id, type, title, message,
                            related_entity_type, related_entity_id, priority)
  SELECT fm.user_id, 'inbound_interaction', 'Coach reached out',
         COALESCE(NULLIF(coach_name, ''), 'A coach')
           || ' had an inbound ' || replace(NEW.type::text, '_', ' ') || '.',
         'interaction', NEW.id, 'high'
  FROM family_members fm
  WHERE fm.family_unit_id = NEW.family_unit_id
    AND fm.user_id IS DISTINCT FROM NEW.logged_by;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_on_inbound_interaction_insert ON public.interactions;
CREATE TRIGGER notify_on_inbound_interaction_insert
  AFTER INSERT ON public.interactions
  FOR EACH ROW
  WHEN (NEW.direction = 'inbound')
  EXECUTE FUNCTION public.notify_on_inbound_interaction();

-- 3. EVENT reminder: 24h before start_date, notify the family. Run daily by cron
--    (see 20260816000003). start_date = tomorrow matches exactly once per event,
--    so no dedup log is needed.
CREATE OR REPLACE FUNCTION public.notify_upcoming_events()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, message,
                            related_entity_type, related_entity_id, priority)
  SELECT r.recipient, 'event', 'Event tomorrow',
         e.name || COALESCE(' at ' || e.location, '') || ' is tomorrow.',
         'event', e.id, 'normal'
  FROM events e
  CROSS JOIN LATERAL (
    SELECT fm.user_id AS recipient
    FROM family_members fm
    WHERE fm.family_unit_id = e.family_unit_id
    UNION
    SELECT e.user_id
    WHERE e.family_unit_id IS NULL
  ) r
  WHERE e.start_date = CURRENT_DATE + 1
    AND r.recipient IS NOT NULL;
END;
$$;
