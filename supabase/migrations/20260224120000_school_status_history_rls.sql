-- ============================================================================
-- RLS policies for school_status_history
-- ============================================================================
-- Fixes: "new row violates row-level security policy for table school_status_history"
-- when updating recruiting status from the school detail page.
--
-- Users may only insert/select rows for schools that belong to a family they
-- are a member of (via schools.family_unit_id and family_members).

-- Ensure RLS is enabled
ALTER TABLE school_status_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if present (idempotent)
DROP POLICY IF EXISTS "Users can view status history for their family schools" ON school_status_history;
DROP POLICY IF EXISTS "Users can insert status history for their family schools" ON school_status_history;

-- SELECT: user can see history for schools in their family
CREATE POLICY "Users can view status history for their family schools"
ON school_status_history
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM schools s
    JOIN family_members fm ON fm.family_unit_id = s.family_unit_id AND fm.user_id = auth.uid()
    WHERE s.id = school_status_history.school_id
  )
);

-- INSERT: user can add history when the school belongs to their family
CREATE POLICY "Users can insert status history for their family schools"
ON school_status_history
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM schools s
    JOIN family_members fm ON fm.family_unit_id = s.family_unit_id AND fm.user_id = auth.uid()
    WHERE s.id = school_status_history.school_id
  )
);
