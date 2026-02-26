# Troubleshooting Guide

## Build Fails

1. **Check environment variables** (SUPABASE_URL, SUPABASE_ANON_KEY)
   - Verify they're set in Xcode scheme: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
2. **Clean build folder:** Cmd+Shift+K
3. **Reset package cache:** File → Packages → Reset Package Caches
4. **Delete derived data:** ~/Library/Developer/Xcode/DerivedData

---

## Tests Fail

1. **@MainActor context:** Use `async func` for tests calling @MainActor code
2. **Mock async calls properly:** Use `Task { await ... }` in tests
3. **UserDefaults caching:** Call `.synchronize()` after writes in tests
4. **Simulator issues:** Reset simulator (Device → Erase All Content and Settings)
5. **Simulator crash when hosting full-screen views:** If the simulator crashes during unit tests with "pointer being freed was not allocated" (often in `swift_task_deinitOnExecutorMainActorBackDeploy`), the cause is usually a @MainActor ViewModel (e.g. CoachDetailViewModel) being deallocated during test teardown off the Main actor. Tests that host `CoachDetailView` in `UIHostingController` should replace `rootView` with `EmptyView()` before the test end and run the main run loop once so the ViewModel is released on Main. See `CoachDetailViewTests` for the pattern. Alternatively, avoid instantiating the full view and test the ViewModel or subviews only (see `CoachDetailAccessibilityTests`).

---

## Supabase Errors

1. **Check RLS policies** (Row Level Security) in Supabase dashboard
2. **Verify table schemas match Swift models** (snake_case → camelCase)
3. **Check Supabase logs** in dashboard for query errors
4. **Verify API keys** are correct and not expired

---

## Session Not Persisting

1. **Verify Keychain entitlements enabled** in Xcode project settings
2. **Check KeychainHelper.save()** is called after login
3. **Verify AuthManager.restoreSession()** runs on app launch
4. **Check simulator Keychain:** May need to reset simulator

---

## Common Xcode Issues

### "Could not find simulator"
- Open Xcode → Window → Devices and Simulators
- Create new iPhone 15 simulator if missing

### "Module not found"
- Clean build folder (Cmd+Shift+K)
- Close Xcode, delete DerivedData, reopen

### "Code signing error"
- Automatic signing should be enabled for development
- Change bundle ID if needed

---

## Performance Issues

### Slow build times
- Clean build folder
- Close other Xcode instances
- Disable live previews if not needed

### Simulator lag
- Allocate more CPU cores: Simulator → Device → CPU
- Close other apps
- Consider using physical device for testing
