# Face ID Authentication — Design

**Date:** 2026-03-08
**Status:** Approved

---

## Overview

Add Face ID as an app-unlock mechanism. After a first successful login, users are offered an opt-in to enable Face ID. On subsequent launches, Face ID gates the existing session restore flow — no credentials are re-stored or re-sent; biometrics just allow the existing Keychain session to be used.

---

## Architecture

### New Components

**`BiometricService`** (`Core/Services/BiometricService.swift`)
- Thin wrapper around `LAContext`
- Checks biometric availability (`canEvaluateBiometrics()`)
- Evaluates policy (`authenticate(reason:) async throws`)
- Not `@MainActor` (service layer convention)

**`BiometricServiceProtocol`** (`Core/Protocols/BiometricServiceProtocol.swift`)
- Protocol interface enabling `MockBiometricService` for tests

### Modified Components

**`AuthManager`**
- `biometricEnabled: Bool` — Keychain-backed computed property
- `enableBiometrics() throws` — saves flag to Keychain
- `disableBiometrics()` — removes flag from Keychain
- `authenticateWithBiometrics() async throws` — delegates to `BiometricService`
- `logout()` — clears `biometricEnabled` flag

**`TheRecruitingCompassApp.swift`**
- On launch: if `biometricEnabled`, show `BiometricLockView` overlaid on content
- On biometric success: dismiss overlay, `restoreSession()` runs normally
- On biometric failure/cancel: navigate to `LoginView`

**`LoginViewModel`**
- `shouldShowBiometricOptIn: Bool` — true after successful login on biometric-capable device
- `enableBiometrics()` — calls `AuthManager.enableBiometrics()`
- `dismissBiometricOptIn()` — clears opt-in state

**`LoginView`**
- `.alert` shown when `shouldShowBiometricOptIn == true`
- "Enable Face ID" → `viewModel.enableBiometrics()`
- "Not Now" → `viewModel.dismissBiometricOptIn()`

**`Info.plist`**
- Adds `NSFaceIDUsageDescription`

---

## Data Flow

### First-Time Setup
```
Successful login
→ AuthManager.isAuthenticated = true
→ LoginView detects success → shows opt-in alert
→ "Enable" → AuthManager.enableBiometrics() → biometricEnabled = true in Keychain
→ "Not Now" → nothing stored
```

### Subsequent App Launches
```
App launch → check biometricEnabled
→ true:  show BiometricLockView
         → LAContext.evaluatePolicy() → Face ID prompt
         → Success:  dismiss lock → restoreSession() runs normally
         → Failure:  navigate to LoginView
→ false: existing flow unchanged
```

### Session Expired During Biometric Unlock
```
Face ID success
→ restoreSession() → session expired
→ refreshAndSaveSession() attempts Supabase refresh
→ Success: user lands on dashboard (transparent)
→ Failure: user lands on LoginView (existing behavior)
```

---

## Error Handling & Edge Cases

| Scenario | Behavior |
|---|---|
| Device has no Face ID / Touch ID | `biometricEnabled` never set; opt-in prompt never shown |
| Face ID locked (too many attempts) | `LAError.biometryLockout` → fall back to LoginView |
| User cancels Face ID prompt | `LAError.userCancel` → fall back to LoginView |
| Face ID disabled in iOS Settings | `canEvaluatePolicy` returns false → fall back to LoginView, clear flag |
| App backgrounded then foregrounded | No re-prompt (session already active) |
| User logs out | `logout()` clears `biometricEnabled` from Keychain |

---

## Testing

### Unit Tests — `BiometricServiceTests`
- `canEvaluateBiometrics()` returns correct availability
- `authenticate()` succeeds with mock `LAContext`
- `authenticate()` throws on lockout, cancel, and unavailable

### Unit Tests — `AuthManagerTests` additions
- `enableBiometrics()` persists flag to Keychain
- `disableBiometrics()` removes flag
- `logout()` clears `biometricEnabled`
- `authenticateWithBiometrics()` delegates to `BiometricService`

### Unit Tests — `LoginViewModelTests` additions
- `shouldShowBiometricOptIn` is true after successful login on biometric-capable device
- `shouldShowBiometricOptIn` is false on non-capable device
- `enableBiometrics()` and `dismissBiometricOptIn()` update state correctly

### Integration Test
- Full flow: login → opt-in → relaunch → biometric gate → dashboard

### Notes
- `LAContext` cannot be triggered in CI simulators
- All tests use `MockBiometricService` via protocol injection
