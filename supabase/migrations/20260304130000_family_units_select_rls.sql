-- ============================================================================
-- RLS Policy: Allow users to SELECT their own family units
-- ============================================================================
-- Root cause: No SELECT policy existed on family_units, which caused two bugs:
--   1. getFamilyUnit() always returned nil (couldn't read family_units rows)
--      → createFamily() tried duplicate INSERTs on every call
--   2. The family_members INSERT policy's EXISTS subquery on family_units
--      always returned false → INSERT into family_members always failed
--
-- Fix: Add a SELECT policy allowing users to see:
--   a) Family units they created (created_by_user_id) — needed during creation
--      so the family_members INSERT policy EXISTS check can see the new row
--   b) Family units they are a member of (via family_members join) — needed for
--      idempotency checks and general family data fetching
-- ============================================================================

CREATE POLICY "Users can view their own family units"
ON family_units
FOR SELECT
USING (
  -- Creator can always see their own family unit
  created_by_user_id = auth.uid()
  OR
  -- Members can see family units they belong to
  EXISTS (
    SELECT 1 FROM family_members fm
    WHERE fm.family_unit_id = family_units.id
    AND fm.user_id = auth.uid()
  )
);
