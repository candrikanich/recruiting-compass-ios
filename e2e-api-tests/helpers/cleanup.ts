import { createAdminClient } from './supabase-client'

export const deleteTestUser = async (email: string): Promise<void> => {
  const admin = createAdminClient()

  const { data: users, error: listError } = await admin.auth.admin.listUsers()

  if (listError) {
    throw new Error(`Failed to list users for cleanup: ${listError.message}`)
  }

  const user = users.users.find(u => u.email === email)

  if (user) {
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id)

    if (deleteError) {
      throw new Error(`Failed to delete test user ${email}: ${deleteError.message}`)
    }
  }
}

export const deleteTestUsers = async (emails: readonly string[]): Promise<void> => {
  const results = await Promise.allSettled(
    emails.map(email => deleteTestUser(email))
  )

  const failures = results.filter(
    (result): result is PromiseRejectedResult => result.status === 'rejected'
  )

  if (failures.length > 0) {
    const messages = failures.map(f => f.reason?.message ?? 'Unknown error')
    throw new Error(`Failed to cleanup some test users: ${messages.join(', ')}`)
  }
}

export const confirmUserEmail = async (email: string): Promise<void> => {
  const admin = createAdminClient()

  const { data: users, error: listError } = await admin.auth.admin.listUsers()

  if (listError) {
    throw new Error(`Failed to list users: ${listError.message}`)
  }

  const user = users.users.find(u => u.email === email)

  if (!user) {
    throw new Error(`User with email ${email} not found`)
  }

  const { error: updateError } = await admin.auth.admin.updateUserById(user.id, {
    email_confirm: true,
  })

  if (updateError) {
    throw new Error(`Failed to confirm email for ${email}: ${updateError.message}`)
  }
}

export const getUserMetadata = async (email: string): Promise<Record<string, unknown> | null> => {
  const admin = createAdminClient()

  const { data: users, error } = await admin.auth.admin.listUsers()

  if (error) {
    throw new Error(`Failed to list users: ${error.message}`)
  }

  const user = users.users.find(u => u.email === email)

  return user?.user_metadata ?? null
}
