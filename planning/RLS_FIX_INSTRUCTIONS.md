# Family Members RLS Fix - Implementation Guide

## Summary

The iOS app was unable to see all family members due to restrictive RLS (Row Level Security) policies. The fix updates the RLS policies to allow users to see all members in families they belong to.

## Root Cause

**Before:**
- RLS policies only allowed users to see their OWN `family_member` record
- iOS app could only fetch 1 member (the logged-in user)
- Web app worked because it uses admin privileges (bypasses RLS)

**After:**
- RLS policies allow users to see ALL members in families they belong to
- iOS app fetches family_members and users separately (no joins needed)
- Matches Supabase best practices for data access control

## Implementation Steps

### Step 1: Update RLS Policies ✅ REQUIRED

Run the SQL in `planning/update-rls-policies.sql`:

```bash
# Option 1: Via Supabase Dashboard
1. Go to https://supabase.com/dashboard/project/YOUR_PROJECT/sql
2. Copy contents of planning/update-rls-policies.sql
3. Click "Run"
4. Verify success

# Option 2: Via Supabase CLI
supabase db push
```

**Expected output:**
```
DROP POLICY
CREATE POLICY
DROP POLICY
CREATE POLICY
```

### Step 2: Verify Policies Were Created

Run this query in SQL Editor:

```sql
SELECT
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename IN ('family_members', 'users')
AND policyname LIKE '%family%'
ORDER BY tablename, policyname;
```

**Expected results:**
```
family_members | Users can view all members in their families | SELECT
users          | Users can view family members' profiles       | SELECT
```

### Step 3: Test iOS App

1. **Clean build:**
   ```bash
   cd TheRecruitingCompass
   xcodebuild clean build -scheme TheRecruitingCompass \
     -destination 'platform=iOS Simulator,name=iPhone 17'
   ```

2. **Run app:** Cmd + R in Xcode

3. **Navigate to Family Management**

4. **Verify all 3 members appear:**
   - Test Player (player)
   - Chris Andrikanich (parent)
   - Test Parent2 (parent)

5. **Check Console logs:**
   ```
   🔍 [FamilyService] fetchFamilyMembers called for familyUnitId: 983b2163-...
   Fetched 3 family member rows
   Fetching user details for 3 user IDs
   Fetched 3 user records
   Returning 3 family members with user details
   ```

## What Changed in iOS Code

### Before (broken):
```swift
// Tried to use inner join - blocked by RLS
let response: [FamilyMember] = try await supabaseManager.client
  .from("family_members")
  .select("*, user:users!inner(*)")
  .eq("family_unit_id", value: familyUnitId)
  .execute()
  .value
```

### After (working):
```swift
// Step 1: Fetch family_members separately
let memberRows = try await supabaseManager.client
  .from("family_members")
  .select("id, user_id, family_unit_id, role, added_at")
  .eq("family_unit_id", value: familyUnitId)
  .execute()
  .value

// Step 2: Fetch users separately
let users = try await supabaseManager.client
  .from("users")
  .select("id, email, full_name, role")
  .in("id", values: userIds)
  .execute()
  .value

// Step 3: Combine results
```

## RLS Policy Details

### family_members Policy
```sql
CREATE POLICY "Users can view all members in their families"
ON family_members
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM family_members fm
    WHERE fm.family_unit_id = family_members.family_unit_id
    AND fm.user_id = auth.uid()
  )
);
```

**What it does:**
- Allows user to SELECT any `family_member` record where:
  - The family_unit_id matches a family the user belongs to
- Example: If user A is in family X, they can see ALL members of family X

### users Policy
```sql
CREATE POLICY "Users can view family members' profiles"
ON users
FOR SELECT
USING (
  id = auth.uid()
  OR
  EXISTS (
    SELECT 1
    FROM family_members fm1
    JOIN family_members fm2 ON fm1.family_unit_id = fm2.family_unit_id
    WHERE fm1.user_id = auth.uid()
    AND fm2.user_id = users.id
  )
);
```

**What it does:**
- Allows user to SELECT any `users` record where:
  - It's their own profile, OR
  - The user is a family member in one of their families
- Example: If user A and user B are in family X, A can see B's profile

## Security Considerations

✅ **Safe:**
- Users can only see members of families they belong to
- No cross-family data leakage
- Follows principle of least privilege

❌ **Does NOT allow:**
- Seeing members of other families
- Seeing users outside their families
- Modifying other users' data (SELECT only)

## Rollback (if needed)

If something goes wrong, revert to restrictive policies:

```sql
-- Revert family_members
DROP POLICY "Users can view all members in their families" ON family_members;
CREATE POLICY "Users can view their own record" ON family_members
FOR SELECT USING (user_id = auth.uid());

-- Revert users
DROP POLICY "Users can view family members' profiles" ON users;
CREATE POLICY "Users can view own profile" ON users
FOR SELECT USING (id = auth.uid());
```

## Clean Up

After confirming everything works, you can delete:
- `planning/family-members-fetch-edge-function.ts` (not needed)
- `planning/DEPLOY_EDGE_FUNCTION.md` (not needed)
