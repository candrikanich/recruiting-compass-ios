-- Adds timezone column to users table
-- US only: America/New_York (default), America/Chicago, America/Denver, America/Los_Angeles
ALTER TABLE users ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'America/New_York'
  CHECK (timezone IN (
    'America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles'
  ));
