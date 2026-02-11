# Code Patterns Reference

## ViewModel Pattern

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

---

## View Pattern

```swift
struct SchoolsListView: View {
  @StateObject var viewModel = SchoolsListViewModel()

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
