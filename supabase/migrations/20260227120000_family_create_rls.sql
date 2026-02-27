-- ============================================================================
-- RLS Policies for Family Creation (Direct Supabase)
-- ============================================================================
-- Allows players to create their own family unit and add themselves as member
-- via iOS app (no web API required).

-- 1. family_units: player can INSERT their own family
-- ============================================================================
CREATE POLICY "Players can create their own family unit"
ON family_units
FOR INSERT
WITH CHECK (player_user_id = auth.uid());

-- 2. family_members: player can add themselves to a family they own
-- ============================================================================
CREATE POLICY "Players can add themselves to their family"
ON family_members
FOR INSERT
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM family_units fu
    WHERE fu.id = family_members.family_unit_id
    AND fu.player_user_id = auth.uid()
  )
);
