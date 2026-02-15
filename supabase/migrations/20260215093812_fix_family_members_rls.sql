-- ============================================================================
-- RLS Policy Updates for Family Members Feature
-- ============================================================================
-- This allows iOS app to fetch all family members without needing Edge Functions
-- Users can see all members in families they belong to

-- 1. Update family_members table policy
-- ============================================================================

-- Drop existing restrictive policy
DROP POLICY IF EXISTS "Users can view their own family member record" ON family_members;
DROP POLICY IF EXISTS "Users can view family members" ON family_members;

-- Create new policy: users can see ALL members in families they belong to
CREATE POLICY "Users can view all members in their families"
ON family_members
FOR SELECT
USING (
  -- User can see family_members if they are also a member of that family
  EXISTS (
    SELECT 1
    FROM family_members fm
    WHERE fm.family_unit_id = family_members.family_unit_id
    AND fm.user_id = auth.uid()
  )
);

-- 2. Update users table policy (if needed)
-- ============================================================================

-- Check if policy exists, drop if too restrictive
DROP POLICY IF EXISTS "Users can view their own profile" ON users;

-- Allow users to view other users who are in their families
CREATE POLICY "Users can view family members' profiles"
ON users
FOR SELECT
USING (
  -- User can view their own profile
  id = auth.uid()
  OR
  -- User can view profiles of people in their families
  EXISTS (
    SELECT 1
    FROM family_members fm1
    JOIN family_members fm2 ON fm1.family_unit_id = fm2.family_unit_id
    WHERE fm1.user_id = auth.uid()
    AND fm2.user_id = users.id
  )
);

-- 3. Verify policies are created
-- ============================================================================

SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename IN ('family_members', 'users')
ORDER BY tablename, policyname;
