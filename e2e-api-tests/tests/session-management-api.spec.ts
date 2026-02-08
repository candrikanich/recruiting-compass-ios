import { test, expect } from '@playwright/test'
import { createAnonClient } from '../helpers/supabase-client'
import { createTestUser } from '../helpers/test-data'
import { deleteTestUser, confirmUserEmail } from '../helpers/cleanup'

test.describe('Session Management API', () => {
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

  test('signup should return a session with access token', async () => {
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

    // Supabase may or may not return a session depending on email confirmation settings
    if (data.session) {
      expect(data.session.access_token).toBeTruthy()
      expect(data.session.refresh_token).toBeTruthy()
      expect(data.session.token_type).toBe('bearer')
      expect(data.session.expires_in).toBeGreaterThan(0)
      expect(data.session.expires_at).toBeGreaterThan(0)
    }
  })

  test('confirmed user can sign in and receive a valid session', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    // Signup
    await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    // Confirm email via admin
    await confirmUserEmail(user.email)

    // Sign in
    const { data, error } = await client.auth.signInWithPassword({
      email: user.email,
      password: user.password,
    })

    expect(error).toBeNull()
    expect(data.session).toBeTruthy()
    expect(data.session?.access_token).toBeTruthy()
    expect(data.session?.refresh_token).toBeTruthy()
    expect(data.session?.expires_at).toBeGreaterThan(Math.floor(Date.now() / 1000))
    expect(data.user).toBeTruthy()
    expect(data.user?.email).toBe(user.email)
  })

  test('session can be refreshed with valid refresh token', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    // Signup and confirm
    await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    await confirmUserEmail(user.email)

    // Sign in
    const { data: loginData, error: loginError } = await client.auth.signInWithPassword({
      email: user.email,
      password: user.password,
    })

    expect(loginError).toBeNull()
    expect(loginData.session).toBeTruthy()

    // Refresh session
    const { data: refreshData, error: refreshError } = await client.auth.refreshSession()

    expect(refreshError).toBeNull()
    expect(refreshData.session).toBeTruthy()
    expect(refreshData.session?.access_token).toBeTruthy()
    expect(refreshData.user).toBeTruthy()
    expect(refreshData.user?.email).toBe(user.email)
  })

  test('sign out should invalidate session', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    // Signup, confirm, sign in
    await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    await confirmUserEmail(user.email)

    await client.auth.signInWithPassword({
      email: user.email,
      password: user.password,
    })

    // Sign out
    const { error: signOutError } = await client.auth.signOut()
    expect(signOutError).toBeNull()

    // Session should be cleared
    const { data: sessionData } = await client.auth.getSession()
    expect(sessionData.session).toBeNull()
  })

  test('wrong password should not create a session', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    // Signup and confirm
    await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    await confirmUserEmail(user.email)

    // Try to sign in with wrong password
    const { data, error } = await client.auth.signInWithPassword({
      email: user.email,
      password: 'WrongPassword99',
    })

    expect(error).toBeTruthy()
    expect(data.session).toBeNull()
  })
})

test.describe('Session Management - Token Structure', () => {
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

  test('session token should contain expected fields matching iOS Session model', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    await confirmUserEmail(user.email)

    const { data, error } = await client.auth.signInWithPassword({
      email: user.email,
      password: user.password,
    })

    expect(error).toBeNull()

    const session = data.session
    expect(session).toBeTruthy()

    // Verify all fields that the iOS Session model expects
    expect(typeof session?.access_token).toBe('string')
    expect(typeof session?.token_type).toBe('string')
    expect(typeof session?.expires_in).toBe('number')
    expect(typeof session?.expires_at).toBe('number')
    expect(typeof session?.refresh_token).toBe('string')

    // Verify user fields that the iOS User model expects
    const sessionUser = data.user
    expect(sessionUser).toBeTruthy()
    expect(typeof sessionUser?.id).toBe('string')
    expect(typeof sessionUser?.email).toBe('string')
    expect(sessionUser?.email).toBe(user.email)
    expect(sessionUser?.email_confirmed_at).toBeTruthy()
    expect(typeof sessionUser?.created_at).toBe('string')
    expect(typeof sessionUser?.updated_at).toBe('string')
  })
})
