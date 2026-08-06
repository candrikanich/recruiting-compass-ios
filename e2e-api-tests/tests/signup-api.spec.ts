import { test, expect } from '@playwright/test'
import { createAnonClient } from '../helpers/supabase-client'
import { createTestUser } from '../helpers/test-data'
import { deleteTestUser, getUserMetadata } from '../helpers/cleanup'
import { isEmailAutoconfirmEnabled } from '../helpers/auth-settings'

test.describe('Signup API - Parent Flow', () => {
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

  test('should create a parent account with correct metadata', async () => {
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
    expect(data.user?.email).toBe(user.email)

    const metadata = await getUserMetadata(user.email)
    expect(metadata).toBeTruthy()
    expect(metadata?.full_name).toBe(user.fullName)
    expect(metadata?.role).toBe('parent')
  })

  test('should return user without confirmed email on signup', async () => {
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

  test('should reject duplicate email signup', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })
    createdEmails.push(user.email)

    // First signup
    const { error: firstError } = await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    expect(firstError).toBeNull()

    // Second signup with same email
    const { data: secondData, error: secondError } = await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: 'Another Name',
          role: 'parent',
        },
      },
    })

    // Supabase returns a fake user (no session) for existing emails to prevent enumeration
    // The key indicator is that no new session is created
    if (secondError) {
      expect(secondError.message).toBeTruthy()
    } else {
      // Supabase may return the existing user without a new session
      expect(secondData.session).toBeNull()
    }
  })

  test('should reject password shorter than 6 characters', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'parent' })

    const { error } = await client.auth.signUp({
      email: user.email,
      password: 'short',
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
        },
      },
    })

    // Supabase enforces minimum 6-char password by default
    expect(error).toBeTruthy()
    if (error) {
      expect(error.message.toLowerCase()).toContain('password')
    }
  })
})

test.describe('Signup API - Student Flow', () => {
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

  test('should create a student account with role metadata', async () => {
    const client = createAnonClient()
    const user = createTestUser({ role: 'student' })
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

    const metadata = await getUserMetadata(user.email)
    expect(metadata?.role).toBe('student')
  })

  test('should create a student account with family code in metadata', async () => {
    const client = createAnonClient()
    const familyCode = 'FAM-TEST1234'
    const user = createTestUser({ role: 'student', familyCode })
    createdEmails.push(user.email)

    const { data, error } = await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
          family_code: familyCode,
        },
      },
    })

    expect(error).toBeNull()
    expect(data.user).toBeTruthy()

    const metadata = await getUserMetadata(user.email)
    expect(metadata?.role).toBe('student')
    expect(metadata?.family_code).toBe(familyCode)
  })

  test('should create a player account with family code in metadata', async () => {
    const client = createAnonClient()
    const familyCode = 'FAM-PLAY5678'
    const user = createTestUser({ role: 'player', familyCode })
    createdEmails.push(user.email)

    const { data, error } = await client.auth.signUp({
      email: user.email,
      password: user.password,
      options: {
        data: {
          full_name: user.fullName,
          role: user.role,
          family_code: familyCode,
        },
      },
    })

    expect(error).toBeNull()
    expect(data.user).toBeTruthy()

    const metadata = await getUserMetadata(user.email)
    expect(metadata?.role).toBe('player')
    expect(metadata?.family_code).toBe(familyCode)
  })
})

test.describe('Signup API - All Roles', () => {
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

  for (const role of ['parent', 'student', 'player'] as const) {
    test(`should accept ${role} role in metadata`, async () => {
      const client = createAnonClient()
      const user = createTestUser({ role })
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

      const metadata = await getUserMetadata(user.email)
      expect(metadata?.role).toBe(role)
    })
  }
})
