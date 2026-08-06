/**
 * Reads the GoTrue `/auth/v1/settings` endpoint to learn how the target stack
 * is configured. Local Supabase stacks default to `mailer_autoconfirm = true`
 * (email auto-confirmed on signup), so any assertion that a freshly signed-up
 * user is *unverified* is only meaningful when autoconfirm is OFF.
 */
type AuthSettings = {
  readonly mailer_autoconfirm: boolean
}

const loadTarget = (): { url: string; anonKey: string } => {
  const url = process.env.SUPABASE_URL
  const anonKey = process.env.SUPABASE_ANON_KEY
  if (!url) throw new Error('SUPABASE_URL environment variable is required')
  if (!anonKey) throw new Error('SUPABASE_ANON_KEY environment variable is required')
  return { url, anonKey }
}

/**
 * True when the target stack auto-confirms email on signup (verification flow
 * disabled). Tests asserting an unverified post-signup state should skip when true.
 */
export const isEmailAutoconfirmEnabled = async (): Promise<boolean> => {
  const { url, anonKey } = loadTarget()
  const response = await fetch(`${url}/auth/v1/settings`, {
    headers: { apikey: anonKey },
  })
  if (!response.ok) {
    throw new Error(`Failed to read auth settings: ${response.status} ${response.statusText}`)
  }
  const settings = (await response.json()) as AuthSettings
  return settings.mailer_autoconfirm === true
}
