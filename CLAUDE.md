# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Quick Start Commands

### Build
```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Run Tests
```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Note:** Local development uses iPhone 17 (available in Xcode 16.4+), while CI/CD uses iPhone 15 (available on GitHub Actions macos-latest). Use whatever iPhone simulator you have available locally.

### Environment Configuration
Supabase credentials must be configured before running:

**Setup Steps (First Time):**
1. **Product → Scheme → Manage Schemes**
2. **Uncheck "Shared"** for TheRecruitingCompass (creates local user scheme)
3. **Product → Scheme → Edit Scheme**
4. **Run** tab → **Arguments** → **Environment Variables**
5. Set values:
   - `SUPABASE_URL`: `https://your-project.supabase.co`
   - `SUPABASE_ANON_KEY`: `your-anon-key-here`

**Why:** Shared scheme (in git) has empty placeholders. Your local user scheme (NOT in git) has real credentials.

---

## Architecture Overview

### MVVM Pattern (Strict Separation)

**Every feature follows:**
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

### Core Layers

**Core/** - Shared infrastructure
- `Services/` - AuthManager (singleton, Keychain-backed), SupabaseManager
- `Models/` - User, Session, AuthError, UserRole
- `Protocols/` - AuthManaging (enables MockAuthManager for tests)
- `Utilities/` - KeychainHelper, DeepLinkHandler
- `Theme/` - AppColors, AppGradients

**Features/** - Feature modules (Auth, Dashboard, Landing, Schools, Coaches)
- Self-contained: Models + ViewModels + Views + Components per feature

**Shared/** - Cross-feature reusable components
- `Components/` - Buttons, form fields, cards
- `Utilities/` - FormValidator, date formatters

### Authentication Flow

```
App Launch → AuthManager.restoreSession() (Keychain → Supabase)
  ├─ Valid Session → isAuthenticated = true → DashboardView
  ├─ Expired Session → Refresh token → Update Keychain
  └─ No Session → isAuthenticated = false → LandingView
      └─ Login/Signup → Save to Keychain → DashboardView
```

**Key Files:**
- `TheRecruitingCompassApp.swift` - Root navigation
- `Core/Services/AuthManager.swift` - Singleton auth manager
- `Core/Utilities/KeychainHelper.swift` - Keychain storage
- `Features/Auth/ViewModels/LoginViewModel.swift` - Login logic

---

## Testing Strategy

**126+ Tests (All Passing)**
- **Unit Tests** - ViewModels, utilities, models
- **Integration Tests** - AuthManager + Supabase flows with mocks
- **Accessibility Tests** - VoiceOver labels, traits
- **E2E Tests** - Full flows with real UI

**Test File Naming:**
- `*Tests.swift` for unit tests
- `*IntegrationTests.swift` for integration tests
- `*AccessibilityTests.swift` for accessibility tests
- `*E2ETests.swift` for E2E UI tests

**Mock Pattern:**
```swift
protocol AuthManaging { /* ... */ }
class MockAuthManager: AuthManaging { /* ... */ }
```

---

## Accessibility (WCAG AA Compliant)

**Requirements:**
- All interactive elements have `.accessibilityLabel()`
- Form fields grouped with `.accessibilityElement(children: .combine)`
- Decorative icons hidden with `.accessibilityHidden(true)`
- Use semantic fonts (.title, .body, .caption) - NEVER `.system(size: 14)`
- Button hit targets minimum 44x44pt

**Testing:**
- Manual VoiceOver: Cmd+F5 (Simulator)
- Dynamic Type: Settings → Accessibility → Display & Text Size

---

## Creating New Screens

**Template:** `TheRecruitingCompass/UI/Screens/_ScreenTemplate/`

**Quick Workflow:**
1. Copy `_ScreenTemplate/` → rename to feature (e.g., `Schools/`)
2. Rename files: `ExampleScreen*` → `SchoolsList*`
3. Update ViewModel: Add @Published properties, async methods
4. Update View: Display ViewModel state, call ViewModel methods
5. Create Service: Add API calls (pure async functions, no @Published)
6. Add to navigation

**See:** `TheRecruitingCompass/UI/Screens/HOW_TO_CREATE_SCREENS.md`

---

## Project Guidelines

### File Organization
- **Never save working files to root** - use `planning/`, `docs/`, etc.
- Test files mirror source structure

### Naming Conventions
- ViewModels: `FeatureNameViewModel` (e.g., `LoginViewModel`)
- Views: `FeatureNameView` (e.g., `LoginView`)
- Services: `FeatureNameService` (e.g., `SchoolsService`)
- Protocols: `FeatureNameManaging` (e.g., `AuthManaging`)

### Thread Safety
- All ViewModels MUST be `@MainActor`
- Services are NOT @MainActor

---

## Documentation & References

**Key Docs:**
- `docs/CODE_PATTERNS.md` - Reusable code patterns
- `docs/TROUBLESHOOTING.md` - Common issues & solutions
- `docs/ACCESSIBILITY_AUDIT.md` - Accessibility testing guide
- `README.md` - Quick start and project overview

**Implementation Guides:**
- `TheRecruitingCompass/UI/Screens/HOW_TO_CREATE_SCREENS.md`
- `planning/iOS_SPEC_Phase1_Login.md` - Login feature spec (reference)
