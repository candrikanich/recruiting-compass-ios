# GitHub Secrets Setup

This document explains how to configure GitHub Secrets for the iOS CI workflow.

## Required Secrets

The workflow requires two secrets to be configured:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SUPABASE_URL` | Your Supabase project URL | `https://your-project.supabase.co` |
| `SUPABASE_ANON_KEY` | Your Supabase anonymous key | `eyJhbGciOiJIUzI1NiIsInR5cCI6...` |

## Setup Instructions

### 1. Navigate to Repository Settings

1. Go to your GitHub repository
2. Click **Settings** (top navigation)
3. In the left sidebar, click **Secrets and variables** → **Actions**

### 2. Add Secrets

For each secret:

1. Click **New repository secret**
2. Enter the **Name** (exactly as shown above)
3. Enter the **Value** (your actual Supabase credentials)
4. Click **Add secret**

### 3. Verify Setup

After adding both secrets, you should see them listed under "Repository secrets":

- ✅ `SUPABASE_URL`
- ✅ `SUPABASE_ANON_KEY`

**Note:** Secret values are hidden after creation. You can only update or delete them.

## Security Notes

- ✅ **NEVER** commit credentials to your repository
- ✅ Secrets are encrypted and only available to GitHub Actions
- ✅ Secret values are masked in workflow logs
- ✅ Use separate credentials for CI/CD vs. local development if possible

## Troubleshooting

### Tests failing with auth errors?

If tests fail with authentication errors:

1. Verify secrets are set correctly (check names match exactly)
2. Ensure your Supabase project allows requests from GitHub Actions IPs
3. Check that the anonymous key has appropriate permissions

### How do I find my Supabase credentials?

1. Go to your [Supabase dashboard](https://supabase.com/dashboard)
2. Select your project
3. Click **Settings** → **API**
4. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon public** key → `SUPABASE_ANON_KEY`

## Related Files

- Workflow definition: `.github/workflows/swift.yml`
- Local environment setup: `CLAUDE.md` (Environment Configuration section)
