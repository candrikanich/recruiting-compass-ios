-- ============================================================================
-- Fix family_units RLS Policy
-- ============================================================================
-- The previous RLS updates didn't include family_units, causing dashboard error

-- Drop any existing restrictive policies
DROP POLICY IF EXISTS "Users can view their own family unit" ON family_units;
DROP POLICY IF EXISTS "Players can view their family unit" ON family_units;

-- Allow users to view family units they belong to
CREATE POLICY "Users can view family units they belong to"
ON family_units
FOR SELECT
USING (
  -- Player can see their own family unit
  player_user_id = auth.uid()
  OR
  -- Parents can see family units they are members of
  EXISTS (
    SELECT 1
    FROM family_members fm
    WHERE fm.family_unit_id = family_units.id
    AND fm.user_id = auth.uid()
  )
);
