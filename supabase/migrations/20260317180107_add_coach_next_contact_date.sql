-- Add next_contact_date and follow_up_threshold_days to coaches table
-- Migration: 20260317180107_add_coach_next_contact_date.sql

ALTER TABLE coaches
  ADD COLUMN IF NOT EXISTS next_contact_date date,
  ADD COLUMN IF NOT EXISTS follow_up_threshold_days int NOT NULL DEFAULT 21
    CHECK (follow_up_threshold_days BETWEEN 1 AND 365);