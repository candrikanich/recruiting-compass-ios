# Sign in with Apple — Web Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Sign in with Apple to the web app's login and signup flows, with new Apple users completing role selection before reaching the Dashboard.

**Architecture:** `useAuth.ts` composable gets a `signInWithApple()` function calling `supabase.auth.signInWithOAuth`. The existing Supabase client already uses `detectSessionInUrl: true` so the `/apple-callback` page receives the session automatically after the Apple OAuth redirect. New users (no role in `user_metadata`) are sent to `/apple-setup` to select a role before reaching Dashboard. The `public.users` table is upserted on role selection to mirror the iOS flow.

**Tech Stack:** Nuxt 3, TypeScript, Supabase JS v2, Vue 3 Composition API, Vitest

**Web repo root:** `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web`

**Spec:** `docs/superpowers/specs/2026-03-15-sign-in-with-apple-design.md` (in iOS repo)

**Prerequisite:** Apple Developer Portal and Supabase configuration from iOS plan Task 0 must be complete before end-to-end testing. Code can be written in parallel.

---

## Chunk 1: Domain Verification + useAuth + UI Buttons

### Task W1: Apple domain verification file

**Files:**
- Create: `public/.well-known/apple-developer-domain-association.txt`

This file must be publicly accessible at `https://myrecruitingcompass.com/.well-known/apple-developer-domain-association.txt` before Apple will allow the Service ID OAuth flow.

- [ ] **Step W1.1 — Create the directory and placeholder file**

```bash
mkdir -p /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/public/.well-known
```

Create `public/.well-known/apple-developer-domain-association.txt` with placeholder content:

```
# Replace this file with the content from Apple Developer Portal.
# Location: Developer Portal → Certificates, Identifiers & Profiles →
#   Service IDs → [your Service ID] → Sign In with Apple → Configure →
#   Domains and Subdomains → Download
```

- [ ] **Step W1.2 — Replace with actual Apple content**

After completing Task 0 (Apple Developer Portal configuration):
1. In Apple Developer Portal, edit the Service ID → Sign in with Apple → Configure
2. Under "Domains and Subdomains", add `myrecruitingcompass.com`
3. Click "Download" next to the domain verification file
4. Replace `public/.well-known/apple-developer-domain-association.txt` with the downloaded content

- [ ] **Step W1.3 — Commit placeholder** *(actual content added after Apple config)*

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add public/.well-known/apple-developer-domain-association.txt
git commit -m "chore: add Apple domain verification file placeholder"
```

---

### Task W2: Add `signInWithApple()` to `useAuth.ts`

**Files:**
- Modify: `composables/useAuth.ts`
- Modify: `composables/useAuth.test.ts` *(create if it doesn't exist — check with `ls composables/*.test.ts`)*

Read `composables/useAuth.ts` in full before editing. The composable uses a singleton Supabase client from `useSupabaseClient()`.

- [ ] **Step W2.1 — Check for existing test file**

```bash
ls /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/composables/*.test.ts 2>/dev/null \
  || ls /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/tests/ 2>/dev/null \
  || echo "no test files found — check project test setup"
```

Also check how tests are run:
```bash
cat /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/package.json | grep -A5 '"test"'
```

- [ ] **Step W2.2 — Write the failing test**

Find or create a test file for `useAuth`. Add:

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'

describe('useAuth - signInWithApple', () => {
  let mockSignInWithOAuth: ReturnType<typeof vi.fn>

  beforeEach(() => {
    mockSignInWithOAuth = vi.fn().mockResolvedValue({ error: null })
    vi.mock('#imports', () => ({
      useSupabaseClient: () => ({
        auth: { signInWithOAuth: mockSignInWithOAuth }
      })
    }))
  })

  it('calls signInWithOAuth with apple provider', async () => {
    const { signInWithApple } = useAuth()
    await signInWithApple()
    expect(mockSignInWithOAuth).toHaveBeenCalledWith(
      expect.objectContaining({ provider: 'apple' })
    )
  })

  it('includes redirectTo pointing to /apple-callback', async () => {
    const { signInWithApple } = useAuth()
    await signInWithApple()
    const call = mockSignInWithOAuth.mock.calls[0][0]
    expect(call.options?.redirectTo).toContain('/apple-callback')
  })

  it('throws when Supabase returns an error', async () => {
    mockSignInWithOAuth.mockResolvedValue({ error: new Error('provider error') })
    const { signInWithApple } = useAuth()
    await expect(signInWithApple()).rejects.toThrow()
  })
})
```

Note: The exact mock setup depends on how `useSupabase.ts` exposes the client. Read `composables/useSupabase.ts` to understand the singleton pattern, then adjust the mock accordingly.

- [ ] **Step W2.3 — Run to verify it fails**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npm run test -- --reporter=verbose 2>&1 | grep -E "FAIL|PASS|error"
```

Expected: test fails — `signInWithApple` does not exist on `useAuth`.

- [ ] **Step W2.4 — Add `signInWithApple` to `useAuth.ts`**

Read `composables/useAuth.ts` in full. Find the `return` statement at the end of the composable. Add to the returned object:

```typescript
async signInWithApple(): Promise<void> {
  const supabase = useSupabaseClient()
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'apple',
    options: {
      redirectTo: `${window.location.origin}/apple-callback`,
      scopes: 'name email',
    }
  })
  if (error) throw error
  // Browser redirects — no further code runs after this point
},
```

Also export the function from the composable's TypeScript return type if the composable uses explicit typing.

- [ ] **Step W2.5 — Run to verify tests pass**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npm run test -- --reporter=verbose 2>&1 | grep -E "FAIL|PASS|error"
```

Expected: 3 tests PASS.

- [ ] **Step W2.6 — Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add composables/useAuth.ts
git commit -m "feat: add signInWithApple to useAuth composable"
```

---

### Task W3: Apple Sign In button — LoginForm + SignupForm

**Files:**
- Modify: `components/Auth/LoginForm.vue`
- Modify: `components/Auth/SignupForm.vue`

Read both files fully before editing. Note the button styling pattern and how `useAuth` is consumed.

- [ ] **Step W3.1 — Read both components**

```bash
cat /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/components/Auth/LoginForm.vue
cat /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/components/Auth/SignupForm.vue
```

Identify: where the primary submit button is, how `useAuth` is imported, any existing loading/error state patterns.

- [ ] **Step W3.2 — Add Apple button to `LoginForm.vue`**

1. Destructure `signInWithApple` from `useAuth()` in the `<script setup>`.
2. Add an `isAppleLoading` ref: `const isAppleLoading = ref(false)`
3. Add a handler:

```typescript
async function handleAppleSignIn() {
  isAppleLoading.value = true
  try {
    await signInWithApple()
  } catch (e) {
    // signInWithApple only fails before redirect — set error if needed
    error.value = 'Sign in with Apple failed. Please try again.'
  } finally {
    isAppleLoading.value = false
  }
}
```

4. After the primary "Sign In" button in the template, add:

```html
<div class="flex items-center gap-3 my-2" aria-hidden="true">
  <div class="h-px flex-1 bg-gray-200" />
  <span class="text-xs text-gray-400">or</span>
  <div class="h-px flex-1 bg-gray-200" />
</div>

<button
  type="button"
  class="w-full flex items-center justify-center gap-3 bg-black text-white rounded-lg py-3 px-4 font-medium hover:bg-gray-900 transition-colors disabled:opacity-50"
  :disabled="isAppleLoading"
  aria-label="Sign in with Apple"
  @click="handleAppleSignIn"
>
  <svg width="16" height="20" viewBox="0 0 814 1000" aria-hidden="true">
    <path fill="currentColor" d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 484.9 8.5 418.3 8.5 356c0-175.9 144.4-268.8 285.3-268.8 75.5 0 138.4 50 185.7 50 45.2 0 116.2-53.5 200.2-53.5zm-37 -232.5c33.3-40.4 57.3-96.9 57.3-153.4 0-7.8-.6-15.6-2-22.3-54.4 2-118.1 36.3-157.6 81.9-30.5 34.8-59.7 91.4-59.7 148.6 0 8.5 1.4 17 2 19.8 3.2.6 8.5 1.4 13.8 1.4 48.6 0 109.5-32.7 146.2-75z"/>
  </svg>
  <span>{{ isAppleLoading ? 'Signing in...' : 'Sign in with Apple' }}</span>
</button>
```

Adjust class names to match the project's existing button styling. Check other buttons in the form for the Tailwind class pattern in use.

- [ ] **Step W3.3 — Add Apple button to `SignupForm.vue`**

Same pattern. Change button label to "Sign up with Apple".

- [ ] **Step W3.4 — Build check**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx nuxi build 2>&1 | grep -E "error|ERROR|✓"
```

Or use the dev server type check:

```bash
npx vue-tsc --noEmit 2>&1 | grep -E "error TS"
```

Expected: no TypeScript errors.

- [ ] **Step W3.5 — Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add components/Auth/LoginForm.vue components/Auth/SignupForm.vue
git commit -m "feat: add Sign in with Apple button to LoginForm and SignupForm"
```

---

## Chunk 2: Callback Page + Role Setup Page

### Task W4: Apple callback page (`/apple-callback`)

**Files:**
- Create: `pages/apple-callback.vue`

The existing Supabase client has `detectSessionInUrl: true`. When Apple redirects the browser to `/apple-callback?code=...`, the Supabase client detects the code in the URL and automatically exchanges it for a session before `onMounted` logic runs. The page only needs to wait for the session, then check the user's role.

- [ ] **Step W4.1 — Read `plugins/auth.client.ts` and `stores/user.ts`**

```bash
cat /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/plugins/auth.client.ts
cat /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/stores/user.ts | head -80
```

Understand how the `SIGNED_IN` event propagates to the user store. The callback page uses `supabase.auth.onAuthStateChange` to know when the session is ready.

- [ ] **Step W4.2 — Create `/apple-callback` page**

Create `pages/apple-callback.vue`:

```vue
<script setup lang="ts">
definePageMeta({ auth: false })  // Don't redirect to login while we're handling auth

const supabase = useSupabaseClient()
const userStore = useUserStore()
const router = useRouter()

onMounted(async () => {
  // detectSessionInUrl: true causes the Supabase client to exchange the code
  // automatically. We listen for SIGNED_IN to know when it's done.
  const { data: { subscription } } = supabase.auth.onAuthStateChange(
    async (event, session) => {
      if (event === 'SIGNED_IN' && session) {
        subscription.unsubscribe()
        const role = session.user.user_metadata?.role as string | undefined
        if (!role) {
          // New Apple user — needs role selection
          await router.push('/apple-setup')
        } else {
          await router.push('/dashboard')
        }
      } else if (event === 'SIGNED_OUT' || event === 'TOKEN_REFRESHED') {
        subscription.unsubscribe()
        await router.push('/login?error=apple_failed')
      }
    }
  )

  // Timeout fallback — if no event fires within 10 seconds, redirect to login
  setTimeout(() => {
    subscription.unsubscribe()
    router.push('/login?error=apple_timeout')
  }, 10_000)
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 mx-auto mb-4" />
      <p class="text-gray-600">Completing sign in…</p>
    </div>
  </div>
</template>
```

Note: Adjust the spinner styling to match your existing loading patterns. Check if there's a `LoadingSpinner` component in the project.

- [ ] **Step W4.3 — Add `/apple-callback` to Supabase allowed redirect URLs** *(if not done in Task 0)*

Supabase Dashboard → Authentication → URL Configuration → add `https://myrecruitingcompass.com/apple-callback` to the Redirect URLs list. Without this, Apple's OAuth will redirect but Supabase will reject the callback.

- [ ] **Step W4.4 — Build check**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx vue-tsc --noEmit 2>&1 | grep -E "error TS"
```

Expected: no TypeScript errors.

- [ ] **Step W4.5 — Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add pages/apple-callback.vue
git commit -m "feat: add /apple-callback page for Apple OAuth session exchange"
```

---

### Task W5: Apple role setup page (`/apple-setup`)

**Files:**
- Create: `pages/apple-setup.vue`

Shown only to new Apple users (no role in `user_metadata`). On submit, upserts into `public.users` and updates `user_metadata`, then redirects to `/dashboard`.

- [ ] **Step W5.1 — Read `UserTypeSelector.vue`**

```bash
cat /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/components/Auth/UserTypeSelector.vue
```

Understand the props/emits API so you can reuse it.

- [ ] **Step W5.2 — Create `/apple-setup` page**

Create `pages/apple-setup.vue`:

```vue
<script setup lang="ts">
definePageMeta({ auth: false })

const supabase = useSupabaseClient()
const userStore = useUserStore()
const router = useRouter()

const selectedRole = ref<'parent' | 'coach' | null>(null)
const isLoading = ref(false)
const errorMessage = ref<string | null>(null)

// Guard: if user already has a role, skip to dashboard
onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    await router.push('/login')
    return
  }
  const existingRole = user.user_metadata?.role as string | undefined
  if (existingRole) {
    await router.push('/dashboard')
  }
})

async function handleContinue() {
  if (!selectedRole.value) return
  isLoading.value = true
  errorMessage.value = null
  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) throw userError ?? new Error('No user session')

    // Update auth metadata
    const { error: updateError } = await supabase.auth.updateUser({
      data: { role: selectedRole.value }
    })
    if (updateError) throw updateError

    // Upsert into public.users (mirrors iOS createAppleUser)
    const { error: upsertError } = await supabase
      .from('users')
      .upsert({
        id: user.id,
        email: user.email,
        full_name: user.user_metadata?.full_name ?? '',
        role: selectedRole.value
      }, { onConflict: 'id' })
    if (upsertError) throw upsertError

    await userStore.initializeUser()  // refresh store
    await router.push('/dashboard')
  } catch (e) {
    errorMessage.value = 'Profile setup failed. Please try again.'
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center p-6">
    <div class="w-full max-w-md">
      <div class="text-center mb-8">
        <h1 class="text-2xl font-bold mb-2">Welcome!</h1>
        <p class="text-gray-600">How will you be using The Recruiting Compass?</p>
      </div>

      <UserTypeSelector
        :selected="selectedRole"
        @select="selectedRole = $event"
      />

      <p v-if="errorMessage" class="mt-4 text-sm text-red-600 text-center">
        {{ errorMessage }}
      </p>

      <button
        class="mt-6 w-full bg-blue-600 text-white rounded-lg py-3 font-medium disabled:opacity-50 hover:bg-blue-700 transition-colors"
        :disabled="!selectedRole || isLoading"
        @click="handleContinue"
      >
        {{ isLoading ? 'Setting up…' : 'Continue' }}
      </button>
    </div>
  </div>
</template>
```

Note: Adjust class names to match the project's existing button/layout styling. Check `pages/signup.vue` for the visual pattern to follow.

- [ ] **Step W5.3 — Build check**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx vue-tsc --noEmit 2>&1 | grep -E "error TS"
```

Expected: no TypeScript errors.

- [ ] **Step W5.4 — Verify `/apple-setup` is excluded from auth middleware**

Open `middleware/auth.ts` and confirm that `/apple-callback` and `/apple-setup` are treated as public routes (not redirected to `/login`). Check the `isProtectedRoute` function — add exceptions if needed:

```typescript
// In isProtectedRoute or the unprotected routes list:
'/apple-callback',
'/apple-setup',
```

- [ ] **Step W5.5 — Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add pages/apple-setup.vue middleware/auth.ts
git commit -m "feat: add /apple-setup role selection page for new Apple users"
```

---

### Task W6: Manual Smoke Tests *(requires Apple config from iOS plan Task 0)*

- [ ] New web user: click "Sign in with Apple" on login page → Apple OAuth → selects role → Dashboard ✓
- [ ] Returning user: click "Sign in with Apple" → no role setup → Dashboard directly ✓
- [ ] Cross-platform: sign in with Apple on iOS → open web → sign in with Apple → same data visible ✓
- [ ] Direct URL: navigate to `/apple-setup` while logged in with role → immediately redirected to `/dashboard` ✓
- [ ] Apple domain verification: `curl https://myrecruitingcompass.com/.well-known/apple-developer-domain-association.txt` → returns Apple-provided JSON content ✓

- [ ] **Final commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add -A
git commit -m "feat: complete web Sign in with Apple implementation"
```
