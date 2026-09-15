-- ============================================================================
-- RLS Policy: Allow creators to delete their own orphaned family_units row
-- ============================================================================
-- Root cause: the membership-conflict recovery path in
-- FamilyServiceImpl+Creation.swift (createFamilyViaDirect) deletes the
-- family_units row it just inserted when it loses the create/membership race
-- to a concurrent caller. No DELETE policy exists on family_units, so RLS
-- silently blocks the cleanup (0 rows affected, no error) and the orphaned
-- row is left behind.
-- ============================================================================

CREATE POLICY "Users can delete family units they created"
ON family_units
FOR DELETE
USING (created_by_user_id = auth.uid());
