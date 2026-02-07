# E2E API Integration Tests

Backend integration tests for TheRecruitingCompass Supabase Auth API.
Uses `@playwright/test` as a test runner (no browser required) to validate signup, email verification, session management, and family code flows.

## Prerequisites

- Node.js 18+
- Supabase project with Auth enabled
- Service Role Key for admin operations (test cleanup, email confirmation)

## Setup

```bash
cd e2e-api-tests
npm install
```

Create a `.env` file from the template:

```bash
cp .env.example .env
```

Fill in your Supabase credentials:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## Running Tests

```bash
# Run all API tests
npm test

# Run specific test suite
npm run test:signup
npm run test:verification
npm run test:session
npm run test:family

# View HTML report
npm run test:report
```

## Test Suites

| Suite | File | Tests |
|-------|------|-------|
| Signup API | `signup-api.spec.ts` | Parent/Student/Player signup, duplicate email, weak password |
| Email Verification | `email-verification-api.spec.ts` | Unverified state, admin confirmation, resend, session refresh |
| Session Management | `session-management-api.spec.ts` | Token structure, refresh, sign out, wrong password |
| Family Code | `family-code-api.spec.ts` | Code storage, parent-student sharing, persistence through login |

## Test Data Cleanup

All tests create users with unique timestamped emails and clean up after themselves via `afterAll` hooks using the Supabase Admin API.

## CI/CD

```bash
# Run with environment variables
SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_SERVICE_ROLE_KEY=... npm test
```

Reports are generated in `playwright-report/` (HTML) and `playwright-results.xml` (JUnit).
