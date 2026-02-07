import { test, expect } from '@playwright/test'
import { createAnonClient } from '../helpers/supabase-client'
import { createTestUser } from '../helpers/test-data'
import { deleteTestUser, getUserMetadata, confirmUserEmail } from '../helpers/cleanup'

test.describe('Family Code API - Parent Creates, Student Joins', () => {
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

  test('parent account should not have family_code in metadata', async () => {
    const client = createAnonClient()
    const parent = createTestUser({ role: 'parent' })
    createdEmails.push(parent.email)

    const { error } = await client.auth.signUp({
      email: parent.email,
      password: parent.password,
      options: {
        data: {
          full_name: parent.fullName,
          role: parent.role,
        },
      },
    })

    expect(error).toBeNull()

    const metadata = await getUserMetadata(parent.email)
    expect(metadata?.role).toBe('parent')
    expect(metadata?.family_code).toBeUndefined()
  })

  test('student with family_code should store it in metadata', async () => {
    const client = createAnonClient()
    const familyCode = 'FAM-ABCD1234'
    const student = createTestUser({ role: 'student', familyCode })
    createdEmails.push(student.email)

    const { error } = await client.auth.signUp({
      email: student.email,
      password: student.password,
      options: {
        data: {
          full_name: student.fullName,
          role: student.role,
          family_code: familyCode,
        },
      },
    })

    expect(error).toBeNull()

    const metadata = await getUserMetadata(student.email)
    expect(metadata?.role).toBe('student')
    expect(metadata?.family_code).toBe(familyCode)
  })

  test('player with family_code should store it in metadata', async () => {
    const client = createAnonClient()
    const familyCode = 'FAM-PLAY9876'
    const player = createTestUser({ role: 'player', familyCode })
    createdEmails.push(player.email)

    const { error } = await client.auth.signUp({
      email: player.email,
      password: player.password,
      options: {
        data: {
          full_name: player.fullName,
          role: player.role,
          family_code: familyCode,
        },
      },
    })

    expect(error).toBeNull()

    const metadata = await getUserMetadata(player.email)
    expect(metadata?.role).toBe('player')
    expect(metadata?.family_code).toBe(familyCode)
  })

  test('student without family_code should not have it in metadata', async () => {
    const client = createAnonClient()
    const student = createTestUser({ role: 'student' })
    createdEmails.push(student.email)

    const { error } = await client.auth.signUp({
      email: student.email,
      password: student.password,
      options: {
        data: {
          full_name: student.fullName,
          role: student.role,
        },
      },
    })

    expect(error).toBeNull()

    const metadata = await getUserMetadata(student.email)
    expect(metadata?.role).toBe('student')
    expect(metadata?.family_code).toBeUndefined()
  })

  test('parent and student can share the same family_code', async () => {
    const client = createAnonClient()
    const familyCode = 'FAM-SHAR7890'

    // Create parent with family_code in metadata (simulating parent generating a code)
    const parent = createTestUser({ role: 'parent' })
    createdEmails.push(parent.email)

    const { error: parentError } = await client.auth.signUp({
      email: parent.email,
      password: parent.password,
      options: {
        data: {
          full_name: parent.fullName,
          role: parent.role,
          family_code: familyCode,
        },
      },
    })

    expect(parentError).toBeNull()

    // Create a fresh client to avoid session conflicts
    const studentClient = createAnonClient()

    // Create student with same family_code
    const student = createTestUser({ role: 'student', familyCode })
    createdEmails.push(student.email)

    const { error: studentError } = await studentClient.auth.signUp({
      email: student.email,
      password: student.password,
      options: {
        data: {
          full_name: student.fullName,
          role: student.role,
          family_code: familyCode,
        },
      },
    })

    expect(studentError).toBeNull()

    // Verify both have the same family_code
    const parentMeta = await getUserMetadata(parent.email)
    const studentMeta = await getUserMetadata(student.email)

    expect(parentMeta?.family_code).toBe(familyCode)
    expect(studentMeta?.family_code).toBe(familyCode)
  })
})

test.describe('Family Code API - Metadata Persistence', () => {
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

  test('family_code persists through email verification and login', async () => {
    const familyCode = 'FAM-PERS4567'
    const student = createTestUser({ role: 'student', familyCode })
    createdEmails.push(student.email)

    // Signup
    const signupClient = createAnonClient()
    const { error: signupError } = await signupClient.auth.signUp({
      email: student.email,
      password: student.password,
      options: {
        data: {
          full_name: student.fullName,
          role: student.role,
          family_code: familyCode,
        },
      },
    })

    expect(signupError).toBeNull()

    // Confirm email
    await confirmUserEmail(student.email)

    // Login with fresh client
    const loginClient = createAnonClient()
    const { data: loginData, error: loginError } = await loginClient.auth.signInWithPassword({
      email: student.email,
      password: student.password,
    })

    expect(loginError).toBeNull()
    expect(loginData.user).toBeTruthy()

    // Verify family_code survived through the full flow
    const metadata = loginData.user?.user_metadata
    expect(metadata?.role).toBe('student')
    expect(metadata?.family_code).toBe(familyCode)
  })
})
