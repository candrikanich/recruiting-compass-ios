# Auth History

## 2026-03-16 — Sign in with Apple (iOS + web)
Native iOS (AppleSignInService nonce/credential, AuthManager exchange, new-user role-setup flow, entitlements, buttons) and web (useAuth signInWithApple, /apple-callback + /apple-setup pages, domain-verification file, middleware).

## 2026-03-10 — Parent login UX fixes
Fixed the biometric-enrollment alert flash (moved to app level), parent re-onboarding (DB family check), and a duplicate-family bug.

## 2026-03-08 — Face ID app-unlock
Face ID gating session restore: BiometricService (+ protocol/mock), AuthManager flag, opt-in prompt, LoginViewModel wiring, BiometricLockView, tests.

## 2026-03-03 — Security hardening
Fixed 8 security-review issues: removed a dead API key, added auth headers, URL-path sanitization, deep-link token validation, family-code length, and log redaction.
