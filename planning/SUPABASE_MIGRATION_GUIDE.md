# Supabase Migration Guide: Add updated_at to interactions

## Problem
The iOS app is failing to fetch interactions because the `Interaction` Swift model expects an `updated_at` field that doesn't exist in the Supabase database.

**Error:**
```
Failed to fetch interactions: The data couldn't be read because it is missing.
Decoding error: keyNotFound(CodingKeys(stringValue: "updated_at", intValue: nil))
```

## Solution Applied

### 1. Swift Model Fix (DONE ✅)
Made `updatedAt` optional in `Interaction.swift`:
```swift
let updatedAt: String?  // Now optional
```

### 2. Database Migration (TODO ⚠️)
Add `updated_at` column to Supabase `interactions` table.

## How to Apply the Migration

### Option A: Supabase SQL Editor (Recommended)

1. **Open Supabase Dashboard**
   - Go to https://app.supabase.com
   - Select your project
   - Navigate to **SQL Editor** in the left sidebar

2. **Run the Migration**
   - Copy the contents of `add_interactions_updated_at.sql`
   - Paste into the SQL Editor
   - Click **Run** or press `Cmd+Enter`

3. **Verify**
   - Check the output for success messages
   - Run the verification queries at the bottom of the SQL file

### Option B: Supabase CLI (Alternative)

```bash
# Install Supabase CLI if needed
brew install supabase/tap/supabase

# Link to your project
supabase link --project-ref <your-project-ref>

# Run migration
supabase db push add_interactions_updated_at.sql
```

## What the Migration Does

1. **Adds Column:** Creates `updated_at TIMESTAMPTZ DEFAULT NOW()`
2. **Backfills Data:** Sets `updated_at = created_at` for existing records
3. **Creates Trigger Function:** Defines `update_updated_at_column()`
4. **Creates Trigger:** Auto-updates `updated_at` on every UPDATE

## Testing After Migration

1. **Run the iOS app** - Interactions should load without errors
2. **Check logs** - No more "keyNotFound" errors
3. **Update an interaction** - Verify `updated_at` changes automatically

## Rollback (if needed)

If you need to revert the migration:

```sql
-- Remove trigger
DROP TRIGGER IF EXISTS update_interactions_updated_at ON interactions;

-- Remove trigger function
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Remove column
ALTER TABLE interactions DROP COLUMN IF EXISTS updated_at;
```

## Long-Term Recommendation

Consider adding `updated_at` columns to all tables for audit tracking:
- `coaches`
- `schools`
- `offers`
- `family_units`
- `user_profiles`

This is a standard practice for tracking when records change.
