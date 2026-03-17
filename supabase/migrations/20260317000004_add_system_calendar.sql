-- Admin-managed table for NCAA recruiting periods, signing days, and testing dates.
-- Updated once per year by the app owner. No user RLS — service role only.
CREATE TABLE IF NOT EXISTS system_calendar (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category     text NOT NULL CHECK (category IN (
                 'signing_day','nli_period',
                 'contact_period','dead_period','quiet_period','evaluation_period',
                 'sat_date','act_date'
               )),
  sport        text,
  division     text CHECK (division IN ('d1','d2','d3') OR division IS NULL),
  label        text NOT NULL,
  start_date   date NOT NULL,
  end_date     date,
  season_year  int NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX system_calendar_label_date_year_idx
  ON system_calendar (label, start_date, season_year);
