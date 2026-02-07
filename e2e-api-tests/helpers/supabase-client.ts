import { createClient } from '@supabase/supabase-js'
import type { SupabaseClient } from '@supabase/supabase-js'

type SupabaseEnv = {
  readonly url: string
  readonly anonKey: string
  readonly serviceRoleKey: string
}

const loadEnv = (): SupabaseEnv => {
  const url = process.env.SUPABASE_URL
  const anonKey = process.env.SUPABASE_ANON_KEY
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

  if (!url) {
    throw new Error('SUPABASE_URL environment variable is required')
  }

  if (!anonKey) {
    throw new Error('SUPABASE_ANON_KEY environment variable is required')
  }

  if (!serviceRoleKey) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY environment variable is required (needed for admin operations)')
  }

  return { url, anonKey, serviceRoleKey }
}

export const createAnonClient = (): SupabaseClient => {
  const env = loadEnv()
  return createClient(env.url, env.anonKey)
}

export const createAdminClient = (): SupabaseClient => {
  const env = loadEnv()
  return createClient(env.url, env.serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    }
  })
}
