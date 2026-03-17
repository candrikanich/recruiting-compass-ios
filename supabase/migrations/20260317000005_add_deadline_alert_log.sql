-- Deduplicates deadline alerts and follow-up reminders.
-- source_table includes 'coaches' for follow-up reminder dedup.
-- alert_days_before: 7/3/0 for deadline alerts; 0 for same-day follow-up dedup.
CREATE TABLE IF NOT EXISTS deadline_alert_log (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid REFERENCES auth.users NOT NULL,
  source_table      text NOT NULL
    CHECK (source_table IN ('user_deadlines','offers','system_calendar','events','coaches')),
  source_id         uuid NOT NULL,
  alert_days_before int NOT NULL,
  sent_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, source_table, source_id, alert_days_before)
);

CREATE INDEX deadline_alert_log_user_idx ON deadline_alert_log (user_id, source_table, source_id);
