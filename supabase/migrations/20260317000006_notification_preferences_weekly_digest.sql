-- Rename daily_digest → weekly_digest in CHECK constraint
-- Add email_enabled column

ALTER TABLE notification_preferences
  DROP CONSTRAINT IF EXISTS notification_preferences_notification_type_check;

ALTER TABLE notification_preferences
  ADD CONSTRAINT notification_preferences_notification_type_check
  CHECK (notification_type IN (
    'follow_up_reminder', 'deadline_alert', 'weekly_digest',
    'inbound_interaction', 'offer', 'event'
  ));

ALTER TABLE notification_preferences
  ADD COLUMN IF NOT EXISTS email_enabled bool NOT NULL DEFAULT true;
