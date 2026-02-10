-- Migration: Add updated_at column to interactions table
-- This fixes the decoding error when fetching interactions from Supabase

-- Step 1: Add updated_at column with default value of NOW()
-- This will populate existing rows with the current timestamp
ALTER TABLE interactions
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Step 2: Backfill updated_at for existing rows where it's NULL
-- Set updated_at to created_at for historical records
UPDATE interactions
SET updated_at = created_at
WHERE updated_at IS NULL;

-- Step 3: Create or replace the trigger function
-- This function will automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- Step 4: Create the trigger
-- This trigger fires BEFORE every UPDATE on the interactions table
DROP TRIGGER IF EXISTS update_interactions_updated_at ON interactions;
CREATE TRIGGER update_interactions_updated_at
BEFORE UPDATE ON interactions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Verification queries (optional - run after migration)
-- 1. Check column was added
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'interactions' AND column_name = 'updated_at';

-- 2. Check trigger was created
-- SELECT trigger_name, event_manipulation, event_object_table
-- FROM information_schema.triggers
-- WHERE trigger_name = 'update_interactions_updated_at';

-- 3. Sample data to verify
-- SELECT id, created_at, updated_at
-- FROM interactions
-- LIMIT 5;
