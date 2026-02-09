# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Build & Test Commands

### Build
```bash
# Open in Xcode
open TheRecruitingCompass/TheRecruitingCompass.xcodeproj

# Build from command line
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Run Tests
```bash
# All tests
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test file in Xcode
# Cmd+U (all tests) or click diamond next to test method
```

### Environment Configuration
Supabase credentials must be configured before running:

**⚠️ IMPORTANT: The shared Xcode scheme has EMPTY environment variable values for security. You MUST configure them locally.**

**Setup Steps (First Time):**
1. **Product → Scheme → Manage Schemes**
2. **Uncheck "Shared"** for TheRecruitingCompass (creates local user scheme)
3. Click **Close**
4. **Product → Scheme → Edit Scheme**
5. **Run** tab → **Arguments** → **Environment Variables**
6. Update the empty values with your real Supabase credentials:
   - `SUPABASE_URL`: `https://your-project.supabase.co`
   - `SUPABASE_ANON_KEY`: `your-anon-key-here`

**Why this approach?**
- ✅ Shared scheme (in git) has empty placeholders
- ✅ Your local user scheme (NOT in git) has real credentials
- ✅ No secrets in version control
- ✅ Easy onboarding for new developers

**Alternative: .env file (Not Recommended)**
```bash
# iOS doesn't automatically load .env files
# Would require custom build script
cp .env.example .env
```

---

## Architecture

### MVVM Pattern (Strict Separation of Concerns)

**Every feature follows this structure:**
```
Feature/
├── Models/              # Data structures (Codable, Identifiable)
├── ViewModels/          # Business logic (@MainActor, @ObservableObject)
├── Views/               # SwiftUI views (presentation only)
└── Components/          # Reusable UI components
```

**Rules:**
- **Service** = Data fetching only (no UI state, no @Published)
- **ViewModel** = State management (@Published properties, async methods)
- **View** = Display state + call ViewModel methods (no business logic)
- **@MainActor** = Required on all ViewModels for thread-safe UI updates
- **Protocol-based DI** = All services have protocol interfaces for testing

### Core Architecture Layers

**Core/** - Shared infrastructure
- `Services/` - AuthManager (singleton, Keychain-backed session), SupabaseManager
- `Models/` - User, Session, AuthError, UserRole
- `Protocols/` - AuthManaging (enables MockAuthManager for tests)
- `Utilities/` - KeychainHelper (generic Keychain CRUD), DeepLinkHandler
- `Theme/` - AppColors, AppGradients (centralized design system)

**Features/** - Feature modules (Auth, Dashboard, Landing, Family)
- Self-contained: Models + ViewModels + Views + Components per feature
- AuthManager and FamilyManager injected via @EnvironmentObject

**Shared/** - Cross-feature reusable components
- `Components/` - Buttons, form fields, cards
- `Utilities/` - FormValidator, date formatters

### Authentication Flow

```
App Launch
  ↓
AuthManager.restoreSession() (Keychain → Supabase)
  ├─ Valid Session → isAuthenticated = true → DashboardView
  ├─ Expired Session → Refresh token → Update Keychain
  └─ No Session → isAuthenticated = false → LandingView
      └─ Login/Signup → Save to Keychain → DashboardView
```

**Key Files:**
- `TheRecruitingCompassApp.swift` - Root navigation (conditional based on AuthManager.isAuthenticated)
- `Core/Services/AuthManager.swift` - Singleton, ObservableObject, handles login/signup/logout/restore
- `Core/Utilities/KeychainHelper.swift` - Generic Keychain storage (Codable support)
- `Features/Auth/ViewModels/LoginViewModel.swift` - Login form state + validation

### Session Persistence
- AuthManager saves Session to Keychain on successful login/signup
- Auto-restores on app launch
- Auto-refreshes expired tokens via Supabase SDK
- Logout clears Keychain + resets AuthManager state

---

## Testing Strategy

**126+ Tests (All Passing)**
- **Unit Tests** - ViewModels, utilities, models (TheRecruitingCompassTests/)
- **Integration Tests** - AuthManager + Supabase flows with mocks
- **Accessibility Tests** - VoiceOver labels, traits, semantic structure (Accessibility/)
- **E2E Tests** - Full flows with real UI (TheRecruitingCompassUITests/E2E/)

**Test File Naming:**
- `*Tests.swift` for unit tests
- `*IntegrationTests.swift` for integration tests
- `*AccessibilityTests.swift` for accessibility tests
- `*E2ETests.swift` for end-to-end UI tests

**Mock Pattern:**
```swift
// Production: AuthManager.shared (real Supabase)
// Testing: MockAuthManager (protocol conformance)
class MockAuthManager: AuthManaging {
  var shouldSucceed = true
  var isAuthenticated = false
  // ... implement protocol methods
}
```

---

## Accessibility (WCAG AA Compliant)

**100% VoiceOver Support:**
- All interactive elements have `.accessibilityLabel()`
- Form fields grouped with `.accessibilityElement(children: .combine)`
- Decorative icons hidden with `.accessibilityHidden(true)`
- Live regions use `.accessibilityAddTraits(.updatesFrequently)`

**Dynamic Type Support:**
- All fonts use SwiftUI semantic fonts (.title, .body, .caption, etc.)
- Icons scale with `@Environment(\.sizeCategory)`
- Button hit targets minimum 44x44pt
- Layouts use flexible frames with `minWidth/minHeight`

**Testing Accessibility:**
- Run accessibility tests: `*AccessibilityTests.swift`
- Manual VoiceOver testing: Cmd+F5 (Simulator)
- Dynamic Type testing: Settings → Accessibility → Display & Text Size

---

## Creating New Screens

**Template:** `TheRecruitingCompass/UI/Screens/_ScreenTemplate/`

**Quick Workflow:**
1. Copy `_ScreenTemplate/` → rename to your feature (e.g., `Schools/`)
2. Rename files: `ExampleScreen*` → `SchoolsList*`
3. Update ViewModel: Add @Published properties, async methods
4. Update View: Display ViewModel state, call ViewModel methods
5. Create Service: Add API calls (pure async functions, no @Published)
6. Add to navigation (update AppRouter if needed)

**See:** `TheRecruitingCompass/UI/Screens/HOW_TO_CREATE_SCREENS.md` for detailed guide

---

## Code Patterns

### ViewModel Pattern
```swift
@MainActor
final class SchoolsListViewModel: ObservableObject {
  @Published var schools: [School] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let schoolsService = SchoolsService()

  func loadSchools() async {
    isLoading = true
    defer { isLoading = false }

    do {
      schools = try await schoolsService.fetchSchools()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
```

### View Pattern
```swift
struct SchoolsListView: View {
  @StateObject var viewModel = SchoolsListViewModel()

  var body: some View {
    List(viewModel.schools) { school in
      Text(school.name)
    }
    .task { await viewModel.loadSchools() }
  }
}
```

### Service Pattern (No UI State)
```swift
final class SchoolsService {
  func fetchSchools() async throws -> [School] {
    let url = URL(string: "https://api.example.com/schools")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([School].self, from: data)
  }
}
```

### Error Handling (User-Facing)
```swift
// Map technical errors to user-friendly messages
enum AuthError: LocalizedError {
  case invalidCredentials
  case networkError

  var errorDescription: String? {
    switch self {
    case .invalidCredentials:
      return "Email or password is incorrect"
    case .networkError:
      return "Unable to connect. Please check your internet connection."
    }
  }
}
```

---

## Supabase Integration

**Manager:** `Core/Services/SupabaseManager.swift`

**Configuration:**
```swift
// Loads from environment variables or .env file
struct SupabaseConfig {
  static let url: String
  static let anonKey: String
}
```

**Common Operations:**
```swift
// Sign in
let (user, session) = try await SupabaseManager.shared.signIn(email:password:)

// Sign up
let (user, session) = try await SupabaseManager.shared.signUp(email:password:fullName:role:familyCode:)

// Sign out
try await SupabaseManager.shared.signOut()

// Refresh session
let user = try await SupabaseManager.shared.refreshSession()
```

**Error Mapping:**
- Supabase errors → AuthError (user-friendly)
- See `Features/Auth/Utilities/AuthErrorMapper.swift`

---

## Navigation

**Root:** `TheRecruitingCompassApp.swift` conditionally shows:
- `LandingView` (unauthenticated)
- `DashboardView` (authenticated)
- Session loading view (checking Keychain)

**Deep Linking:**
- `Core/Utilities/DeepLinkHandler.swift` parses URLs
- Handled in `TheRecruitingCompassApp.onOpenURL`
- Example: Password reset links open `ResetPasswordView`

---

## Dashboard Implementation Status

**Current State:** 85% complete
- ✅ All UI components built
- ✅ Parent preview mode working
- ✅ Data models defined
- ❌ Data fetch failing (Supabase query error)
- ❌ Navigation to detail pages missing
- ❌ Some widgets incomplete (recruiting packet, at-a-glance summary)

**See:** `planning/DASHBOARD_IMPLEMENTATION_PLAN.md` for detailed roadmap

---

## Project-Specific Guidelines

### File Organization
- **Never save working files to root** - use `planning/`, `docs/`, etc.
- Test files mirror source structure: `Features/Auth/Views/LoginView.swift` → `TheRecruitingCompassTests/Features/Auth/Views/LoginViewTests.swift`

### Naming Conventions
- ViewModels: `FeatureNameViewModel` (e.g., `LoginViewModel`)
- Views: `FeatureNameView` (e.g., `LoginView`)
- Services: `FeatureNameService` (e.g., `SchoolsService`)
- Protocols: `FeatureNameManaging` or `FeatureNameProviding` (e.g., `AuthManaging`)

### Thread Safety
- All ViewModels MUST be `@MainActor` (UI updates on main thread)
- Services are NOT @MainActor (async/await handles threading)

### Accessibility Requirements
- New components MUST have `.accessibilityLabel()` and `.accessibilityHint()` where appropriate
- Interactive elements MUST have `.accessibilityAddTraits(.isButton)` or similar
- Decorative elements MUST be `.accessibilityHidden(true)`
- Write accessibility tests for all new components

### Dynamic Type Requirements
- Use semantic fonts (.title, .body, .caption) - NEVER `.system(size: 14)`
- Icons scale with `@Environment(\.sizeCategory)`
- Button hit targets minimum 44x44pt (use `.frame(minHeight: 44)`)

---

## Common Issues & Solutions

### Build Fails
1. Check environment variables (SUPABASE_URL, SUPABASE_ANON_KEY)
2. Clean build folder: Cmd+Shift+K
3. Reset package cache: File → Packages → Reset Package Caches

### Tests Fail
1. Check @MainActor context: Use `async func` for tests calling @MainActor code
2. Mock async calls properly: Use `Task { await ... }` in tests
3. UserDefaults caching: Call `.synchronize()` after writes in tests

### Supabase Errors
1. Check RLS policies (Row Level Security)
2. Verify table schemas match Swift models (snake_case → camelCase)
3. Check Supabase logs in dashboard for query errors

### Session Not Persisting
1. Verify Keychain entitlements enabled
2. Check KeychainHelper.save() is called after login
3. Verify AuthManager.restoreSession() runs on app launch

---

## Documentation

**Key Handoff Documents:**
- `HANDOFF_SESSION_5.md` - Latest session summary (Dynamic Type implementation)
- `planning/DASHBOARD_IMPLEMENTATION_PLAN.md` - Dashboard roadmap
- `docs/ACCESSIBILITY_AUDIT.md` - Accessibility testing guide
- `README.md` - Quick start and project overview

**Implementation Guides:**
- `TheRecruitingCompass/UI/Screens/HOW_TO_CREATE_SCREENS.md` - Step-by-step screen creation
- `planning/iOS_SPEC_Phase1_Login.md` - Login feature spec (reference implementation)
