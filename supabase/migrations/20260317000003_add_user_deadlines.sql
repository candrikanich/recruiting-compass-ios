CREATE TABLE IF NOT EXISTS user_deadlines (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES auth.users NOT NULL,
  school_id     uuid REFERENCES schools(id) ON DELETE SET NULL,
  label         text NOT NULL,
  deadline_date date NOT NULL,
  category      text NOT NULL CHECK (category IN (
                  'application', 'decision', 'financial_aid', 'visit', 'custom'
                )),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE user_deadlines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_deadlines: users manage own"
  ON user_deadlines FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX user_deadlines_user_date_idx ON user_deadlines (user_id, deadline_date);
