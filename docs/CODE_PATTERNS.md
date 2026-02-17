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

## Keychain Storage

```swift
// Save to Keychain
let session = Session(accessToken: "...", refreshToken: "...")
try KeychainHelper.save(session, service: "auth", account: "session")

// Load from Keychain
if let session: Session = try KeychainHelper.load(service: "auth", account: "session") {
  // Restore session
}

// Delete from Keychain
try KeychainHelper.delete(service: "auth", account: "session")
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
