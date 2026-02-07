type TestUserParams = {
  readonly role: 'parent' | 'student' | 'player'
  readonly familyCode?: string
  readonly emailPrefix?: string
}

type TestUser = {
  readonly fullName: string
  readonly email: string
  readonly password: string
  readonly role: 'parent' | 'student' | 'player'
  readonly familyCode: string | undefined
}

const generateTimestamp = (): string =>
  `${Date.now()}-${Math.random().toString(36).substring(2, 8)}`

export const createTestUser = (params: TestUserParams): TestUser => {
  const timestamp = generateTimestamp()
  const prefix = params.emailPrefix ?? `test-${params.role}`

  return {
    fullName: `Test ${params.role.charAt(0).toUpperCase() + params.role.slice(1)}`,
    email: `${prefix}+${timestamp}@example.com`,
    password: 'StrongPass1',
    role: params.role,
    familyCode: params.familyCode,
  }
}

export const createWeakPasswords = (): readonly string[] => [
  'short',
  'nouppercase1',
  'NOLOWERCASE1',
  'NoNumbers',
  'Ab1',
]

export const createValidFamilyCode = (): string =>
  `FAM-${generateRandomAlphanumeric(8)}`

export const createInvalidFamilyCodes = (): readonly string[] => [
  'INVALID',
  'FAM-short',
  'FAM-toolongcode',
  'fam-abcd1234',
  'FAM_ABCD1234',
  'FAM-abcd1234',
]

const generateRandomAlphanumeric = (length: number): string => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  return Array.from({ length }, () => chars.charAt(Math.floor(Math.random() * chars.length))).join('')
}
