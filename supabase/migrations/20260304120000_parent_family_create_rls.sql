-- ============================================================================
-- RLS Policies: Allow parents to create family units (iOS direct Supabase)
-- ============================================================================
-- Root cause: The existing INSERT policies for family_units and family_members
-- check `player_user_id = auth.uid()`, which is never set by the iOS app
-- (only `created_by_user_id` is set). Parents also have no INSERT policy at all.
--
-- Fix: Add policies using `created_by_user_id`, which is what the iOS app sends.
-- These cover both parents creating families and serve as a correct fallback
-- for player-created families too.
-- ============================================================================

-- 1. Allow any authenticated user to create a family unit they own
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can create their own family unit"
ON family_units
FOR INSERT
WITH CHECK (created_by_user_id = auth.uid());

-- 2. Allow any user to add themselves as a member of a family they created
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can add themselves to families they own"
ON family_members
FOR INSERT
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM family_units fu
    WHERE fu.id = family_members.family_unit_id
    AND fu.created_by_user_id = auth.uid()
  )
);
