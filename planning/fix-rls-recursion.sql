-- ============================================================================
-- Fix Infinite Recursion in family_members RLS Policy
-- ============================================================================

-- STEP 1: Drop the problematic policy
DROP POLICY IF EXISTS "Users can view all members in their families" ON family_members;

-- STEP 2: Create a helper function that bypasses RLS
-- This function checks if a user is a member of a given family
CREATE OR REPLACE FUNCTION user_is_family_member(family_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER  -- This bypasses RLS to prevent infinite recursion
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM family_members
    WHERE family_unit_id = family_id
    AND user_id = auth.uid()
  );
$$;

-- STEP 3: Create the policy using the helper function
CREATE POLICY "Users can view all members in their families"
ON family_members
FOR SELECT
USING (
  -- User can see family members if they are also a member of that family
  user_is_family_member(family_unit_id)
);

-- STEP 4: Grant execute permission on the function
GRANT EXECUTE ON FUNCTION user_is_family_member(uuid) TO authenticated;
