# Security Remediation Summary

**Date:** February 19, 2026  
**Context:** Security & Auth Review recommendations

## Implemented

### 1. Keychain session injection into Supabase client

**Issue:** On cold start, the Supabase client could have empty session storage while AuthManager showed the user as logged in (from Keychain), causing API calls to fail or return empty data.

**Fix:**
- Added `setSession(accessToken:refreshToken:)` to `SupabaseManaging` protocol and `SupabaseManager`
- `AuthManager.refreshAndSaveSession()` now calls `setSession` with the Keychain session before `refreshSession()`

**Files:** `Core/Protocols/SupabaseManaging.swift`, `Core/Services/SupabaseManager.swift`, `Core/Services/AuthManager.swift`

### 2. Removed hardcoded Supabase credentials

**Issue:** Real project URL and anon key in `docs/VISUAL_QA_TESTING_GUIDE.md` were committed to version control.

**Fix:** Replaced with placeholders; added guidance to use Supabase Dashboard for values and rotate if credentials were exposed.

**File:** `docs/VISUAL_QA_TESTING_GUIDE.md`

### 3. RLS migrations

**Issue:** `fix-rls-recursion.sql` and `fix-family-units-rls.sql` were in planning/ and not versioned as migrations.

**Fix:** Added `supabase/migrations/20260219120000_fix_rls_recursion_and_family_units.sql`:
- Recursion-safe `family_members` policy using `user_is_family_member()` SECURITY DEFINER function
- `family_units` RLS policy for users to view units they belong to

**File:** `supabase/migrations/20260219120000_fix_rls_recursion_and_family_units.sql`

---

## Manual steps required

1. **Rotate Supabase anon key** – If the credentials in `docs/VISUAL_QA_TESTING_GUIDE.md` were ever committed, rotate the anon key in Supabase Dashboard → Settings → API.

2. **Apply migrations** – Run `supabase db push` or apply the new migration in the Supabase SQL editor for each environment.

3. **Verify RLS** – Confirm RLS is enabled and correct on all tables: schools, coaches, documents, notifications, events, interactions, performance_metrics, user_preferences, tasks, athlete_tasks, school_status_history, offers, suggestions, communication_templates, and related storage buckets.
