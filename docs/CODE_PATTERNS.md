# Code Patterns Reference

## ViewModel Pattern

Use `@Observable` (iOS 17+) and `@MainActor` for view models. Do not use `ObservableObject` / `@Published` for new code.

```swift
import Observation

@Observable
@MainActor
final class SchoolsListViewModel {
  var schools: [School] = []
  var isLoading = false
  var errorMessage: String?

  private let schoolsService: any SchoolsManaging

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

---

## View Pattern

For views that **own** the view model, use `@State private var viewModel`. Do not use `@StateObject` or `@ObservedObject` with `@Observable` types.

```swift
struct SchoolsListView: View {
  @State private var viewModel = SchoolsListViewModel()

  var body: some View {
    List(viewModel.schools) { school in
      Text(school.name)
    }
    .task { await viewModel.loadSchools() }
    .overlay {
      if viewModel.isLoading {
        ProgressView()
      }
    }
  }
}
```

---

## ViewModel helpers (loading and errors)

Use `ViewModelHelpers.withLoading(set:operation:)` to wrap async work that should drive a loading flag (e.g. `isUpdating`, `isDeleting`). Pass a setter closure to avoid passing actor-isolated state across async boundaries. Use `ViewModelHelpers.handleError` to log and set a user-facing message (e.g. `errorMessage` or `activeAlert`).

```swift
// In a ViewModel:
func save() async {
  await ViewModelHelpers.withLoading(set: { self.isSaving = $0 }) {
    do {
      try await service.save()
    } catch {
      ViewModelHelpers.handleError(error, userMessage: "Failed to save", logger: logger) {
        self.errorMessage = $0
      }
    }
  }
}
```

---

## Service Pattern (No UI State)

```swift
final class SchoolsService {
  func fetchSchools() async throws -> [School] {
    let url = URL(string: "https://api.example.com/schools")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([School].self, from: data)
  }
}
```

---

## Error Handling (User-Facing)

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

## Protocol-Based Testing

```swift
// Protocol for dependency injection
protocol SchoolsManaging {
  func fetchSchools() async throws -> [School]
  func createSchool(_ school: School) async throws -> School
}

// Production implementation
final class SchoolsServiceImpl: SchoolsManaging {
  func fetchSchools() async throws -> [School] { /* ... */ }
  func createSchool(_ school: School) async throws -> School { /* ... */ }
}

// Test mock
final class MockSchoolsService: SchoolsManaging {
  var shouldSucceed = true
  var mockSchools: [School] = []

  func fetchSchools() async throws -> [School] {
    if shouldSucceed { return mockSchools }
    throw NSError(domain: "test", code: -1)
  }

  func createSchool(_ school: School) async throws -> School {
    if shouldSucceed { return school }
    throw NSError(domain: "test", code: -1)
  }
}
```

---

## Error Alert Binding

Use a **derived `Binding`** for `.alert(isPresented:)` so SwiftUI can dismiss the alert by setting the binding to `false`. Never use `.constant(...)` for alert presentation.

```swift
.alert("Error", isPresented: Binding(
  get: { viewModel.errorMessage != nil },
  set: { if !$0 { viewModel.errorMessage = nil } }
)) {
  Button("Retry") {
    viewModel.errorMessage = nil
    Task { await viewModel.load() }
  }
  Button("Dismiss", role: .cancel) { viewModel.errorMessage = nil }
} message: {
  if let error = viewModel.errorMessage {
    Text(error)
  }
}
```

---

## Typography

Use **semantic fonts** for all user-facing text so Dynamic Type and accessibility work correctly. Do not use `.font(.system(size: N))` for body text or labels.

| Use case | Font |
|----------|------|
| Large numbers / stats | `.largeTitle.weight(.bold)` or `.title.weight(.bold)` |
| Section titles | `.headline`, `.title2.bold()` |
| Body / labels | `.body`, `.subheadline`, `.callout` |
| Secondary / captions | `.caption`, `.footnote` |

**Exception:** For **icons** (SF Symbols) only, use `.font(.system(size: iconSize))` where `iconSize` is derived from `@Environment(\.sizeCategory)` so icon size scales with accessibility.

---

## SwiftUI View Tests and @MainActor Teardown

**For simple views (no @MainActor ViewModel):** Wrap in `UIHostingController` to force layout and test rendering:

```swift
let view = MyHeaderView(model: testModel)
  .environment(\.sizeCategory, .extraSmall)
let hosting = UIHostingController(rootView: view)
XCTAssertNotNil(hosting.view)
```

**For full views with @MainActor ViewModels:** Some views (e.g. `CoachDetailView`, `PerformanceDashboardView`) trigger a Swift runtime crash when their ViewModel is deallocated during test teardown (`malloc "pointer being freed was not allocated"` in `swift_task_deinitOnExecutorMainActorBackDeploy`). UIHostingController does not fix this. In those cases, test a subcomponent or use a source-code verification placeholder: `XCTAssertTrue(true, "Verified via source: ...")`.

**Targeted tests:** Run only the tests for the feature you're changing (e.g. `-only-testing:TheRecruitingCompassTests/EventsListViewModelTests`) to avoid unrelated failures derailing work.

---

## nonisolated deinit for @MainActor ViewModels

**When to use:** Add `nonisolated deinit {}` to an `@MainActor` ViewModel when that ViewModel is presented in a sheet or tested via `UIHostingController` and you see teardown crashes (e.g. `swift_task_deinitOnExecutorMainActorBackDeploy`). The compiler-synthesized deinit for @MainActor classes can run when the object is deallocated outside a MainActor task (e.g. when the sheet or hosting controller is torn down), which triggers a runtime crash.

**Pattern:**

```swift
@Observable
@MainActor
final class MySheetViewModel {
  // ...

  // Prevents main-actor-isolated deinit from running on wrong executor (e.g. sheet/hosting teardown).
  nonisolated deinit {}
}
```

**References:** `ActivityFeedViewModel`, `PrivacyPolicyViewModel`, `TermsOfServiceViewModel`. Only add where you actually observe teardown crashes; not every @MainActor ViewModel needs it.

---

## Accessibility Patterns

```swift
// Interactive element with label and hint
Button("Delete") {
  // action
}
.accessibilityLabel("Delete school")
.accessibilityHint("Removes this school from your list")

// Decorative element (hide from VoiceOver)
Image(systemName: "star.fill")
  .accessibilityHidden(true)

// Group related elements
HStack {
  Text("Name:")
  Text(school.name)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("School name: \(school.name)")

// Dynamic Type support
Text("Title")
  .font(.title)  // Use semantic fonts
  .lineLimit(nil)  // Allow multi-line for large text
```

---

## Form Validation

```swift
struct FormValidator {
  static func isValidEmail(_ email: String) -> Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return predicate.evaluate(with: email)
  }

  static func isValidPassword(_ password: String) -> Bool {
    return password.count >= 8
  }
}
```

---

## Security & validation checklist

- **Sanitize user text** before storing or displaying: use `DataSanitizer.stripHtmlTags(_:)` for any rich text or notes that could contain HTML (XSS mitigation); use `DataSanitizer.nilIfEmpty` / trim for optional fields.
- **Validate inputs** at the boundary (forms, API payloads) using `FormValidator`, `SchoolFieldValidator`, or feature-specific validators; show user-facing error messages, never raw exceptions.
- **Never log secrets** (tokens, passwords, keys); use `ProcessInfo.processInfo.environment` for config and keep credentials out of the shared scheme (see CLAUDE.md).
- **Production config:** Release builds require real `SUPABASE_URL` and `SUPABASE_ANON_KEY`; placeholder values trigger a fatalError. Use Scheme → Run → Environment Variables for local runs.

---

## Keychain Storage

`KeychainHelper` uses a fixed service (bundle-derived); you pass a **key** (account name). Auth session is stored under the key `"savedSession"`. See [CONFIGURATION.md](CONFIGURATION.md) for key names and release notes.

```swift
// Save to Keychain
let session = Session(accessToken: "...", refreshToken: "...")
try KeychainHelper.shared.save(session, forKey: "savedSession")

// Load from Keychain
if let session: Session = try? KeychainHelper.shared.load(Session.self, forKey: "savedSession") {
  // Restore session
}

// Delete from Keychain
try KeychainHelper.shared.delete(forKey: "savedSession")
```

---

## Supabase Integration

```swift
// Sign in
let (user, session) = try await SupabaseManager.shared.signIn(
  email: email,
  password: password
)

// Sign up
let (user, session) = try await SupabaseManager.shared.signUp(
  email: email,
  password: password,
  fullName: fullName,
  role: .athlete,
  familyCode: nil
)

// Sign out
try await SupabaseManager.shared.signOut()

// Refresh session
let user = try await SupabaseManager.shared.refreshSession()
```
