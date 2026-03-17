-- supabase/migrations/20260315000002_add_notification_preferences.sql
CREATE TABLE IF NOT EXISTS notification_preferences (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid REFERENCES auth.users NOT NULL,
  notification_type   text NOT NULL
    CHECK (notification_type IN (
      'follow_up_reminder', 'deadline_alert', 'daily_digest',
      'inbound_interaction', 'offer', 'event'
    )),
  push_enabled        bool NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, notification_type)
);

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notification_preferences: users manage own"
  ON notification_preferences FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
