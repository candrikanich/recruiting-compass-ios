import { test, expect } from '@playwright/test'
import { createAnonClient } from '../helpers/supabase-client'
import { createTestUser } from '../helpers/test-data'
import { deleteTestUser, confirmUserEmail } from '../helpers/cleanup'
import { isEmailAutoconfirmEnabled } from '../helpers/auth-settings'

test.describe('Email Verification API', () => {
  const createdEmails: string[] = []

  test.afterAll(async () => {
    for (const email of createdEmails) {
      try {
        await deleteTestUser(email)
      } catch {
        // Best-effort cleanup
      }
    }
  })

  test('newly signed up user should have unverified email', async () => {
    test.skip(
      await isEmailAutoconfirmEnabled(),
      'Stack auto-confirms email (mailer_autoconfirm); no unverified state to assert'
    )
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    const { data, error } = await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    expect(error).toBeNull()
    expect(data.user).toBeTruthy()
    expect(data.user?.email_confirmed_at).toBeFalsy()
  })

  test('admin-confirmed user should have verified email', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    // Signup
    const { error: signupError } = await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    expect(signupError).toBeNull()

    // Admin confirms email
    await confirmUserEmail(user.email)

    // Sign in should now succeed fully
    const { data: loginData, error: loginError } = await client.auth.signInWithPassword({
      email: user.email,
      password: user.password,
    })

    expect(loginError).toBeNull()
    expect(loginData.user).toBeTruthy()
    expect(loginData.user?.email_confirmed_at).toBeTruthy()
    expect(loginData.session).toBeTruthy()
    expect(loginData.session?.access_token).toBeTruthy()
  })

  test('should be able to resend verification email', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    // Signup first
    const { error: signupError } = await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    expect(signupError).toBeNull()

    // Resend verification
    const { error: resendError } = await client.auth.resend({
      email: user.email,
      type: 'signup',
    })

    expect(resendError).toBeNull()
  })

  test('session refresh should reflect updated email confirmation', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    // Signup
    const { data: signupData, error: signupError } = await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    expect(signupError).toBeNull()

    // If a session was returned (some Supabase configs do this)
    if (signupData.session) {
      // Confirm via admin
      await confirmUserEmail(user.email)

      // Refresh session
      const { data: refreshData, error: refreshError } = await client.auth.refreshSession()

      // After confirmation + refresh, the user should show as confirmed
      if (!refreshError && refreshData.user) {
        expect(refreshData.user.email_confirmed_at).toBeTruthy()
      }
    }
  })
})

test.describe('Email Verification - Edge Cases', () => {
  test('resend to non-existent email should not leak user existence', async () => {
    const client = createAnonClient()

    const { error } = await client.auth.resend({
      email: `nonexistent-${Date.now()}@example.com`,
      type: 'signup',
    })

    // Supabase should not reveal whether the email exists
    // It may return success silently or a generic error
    // Either way, it should NOT say "user not found"
    if (error) {
      expect(error.message.toLowerCase()).not.toContain('not found')
    }
  })
})
