# TheRecruitingCompass iOS (Fresh Start)

Modern iOS app with authentication, signup, and email verification flows. Built with SwiftUI, MVVM architecture, and Supabase backend.

## Features

✅ **Authentication**
- Email/password login with session persistence
- Auto-login on app restart
- Token refresh on expiration
- Secure Keychain storage

✅ **Signup & Verification**
- Multi-step signup (role selection → form → verification)
- Email verification with polling
- Family code support for student enrollment
- Real-time password strength validation

✅ **Accessibility** (WCAG AA Compliant)
- 100% VoiceOver support
- Dynamic Type support (all text sizes)
- ARIA labels and semantic structure
- 126+ automated accessibility tests

## Quick Start

### Prerequisites

- Xcode 16+
- iOS 17+ deployment target
- Supabase account (free tier works: https://app.supabase.com)

### 1. Configure Supabase

**Get Your Credentials:**
1. Log in to Supabase dashboard
2. Create new project or use existing
3. Navigate to **Project Settings** → **API**
4. Copy:
   - **URL**: Project URL (starts with `https://`)
   - **Anon Key**: Anon public key

**Set Environment Variables in Xcode:**

⚠️ **IMPORTANT:** The shared scheme has empty environment variable values for security. Follow these steps to configure them locally:

1. Open `TheRecruitingCompass.xcodeproj`
2. **Product** → **Scheme** → **Manage Schemes**
3. **Uncheck "Shared"** for TheRecruitingCompass (creates local user scheme - NOT in git)
4. Click **Close**
5. **Product** → **Scheme** → **Edit Scheme**
6. Select **Run** tab → **Arguments** section
7. Update the empty environment variables with your real credentials:
   - `SUPABASE_URL`: `https://your-project.supabase.co`
   - `SUPABASE_ANON_KEY`: `your-anon-key`
8. Click **Close**

**Why this approach?**
- ✅ Shared scheme (in git) keeps empty placeholders
- ✅ Your local user scheme (NOT in git) has real credentials
- ✅ No secrets in version control

**Alternative (via .env file - Not Recommended):**
iOS doesn't automatically load `.env` files. See `.env.example` for format.
⚠️ Never commit `.env` - it's in `.gitignore`

### 2. Build & Run

```bash
# Open in Xcode
open TheRecruitingCompass.xcodeproj

# Build for simulator
Cmd+B

# Run on simulator
Cmd+R
```

### 3. Run Tests

```bash
# Run all tests
Cmd+U

# Or via command line
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Project Structure

```
TheRecruitingCompass/
├── App/                          # App entry point
│   ├── TheRecruitingCompassApp.swift
│   └── ContentView.swift         # Home screen
├── Data/
│   ├── Models/                   # Data structures (School, Coach, etc)
│   └── Services/                 # API calls (SchoolsService, CoachesService)
├── UI/
│   ├── Screens/
│   │   ├── _ScreenTemplate/      # 👈 COPY THIS FOR NEW SCREENS
│   │   │   ├── ExampleScreenViewModel.swift
│   │   │   └── ExampleScreenView.swift
│   │   ├── Schools/              # Example: Schools list/detail
│   │   └── HOW_TO_CREATE_SCREENS.md
│   ├── Components/               # Reusable UI components
│   └── ViewModels/               # Optional: shared ViewModels
└── Navigation/                   # Router, navigation logic
```

---

## The Pattern (Every Screen Follows This)

### 1. Create Model
```swift
// Data/Models/School.swift
struct School: Codable {
    let id: UUID
    let name: String
    let city: String
}
```

### 2. Create Service
```swift
// Data/Services/SchoolsService.swift
final class SchoolsService {
    func fetchSchools() async throws -> [School] {
        // API call here
    }
}
```

### 3. Create ViewModel
```swift
// UI/Screens/Schools/SchoolsListViewModel.swift
@MainActor
final class SchoolsListViewModel: ObservableObject {
    @Published var schools: [School] = []
    @Published var isLoading = false

    private let schoolsService = SchoolsService()

    func loadSchools() async {
        isLoading = true
        do {
            schools = try await schoolsService.fetchSchools()
        } catch {
            // handle error
        }
    }
}
```

### 4. Create View
```swift
// UI/Screens/Schools/SchoolsListView.swift
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

---

## Creating Your First Screen

1. **Open** `UI/Screens/HOW_TO_CREATE_SCREENS.md`
2. **Follow** the step-by-step guide
3. **Build** (Cmd+R)

---

## Key Principles

- **Service** = Data fetching only (no UI logic)
- **ViewModel** = State management (published properties)
- **View** = Display state + call ViewModel methods
- **@MainActor** = Thread-safe UI updates
- **@Published** = Automatic UI updates when value changes
- **async/await** = Modern async calls

---

## Common Tasks

### Add a new screen
See `UI/Screens/HOW_TO_CREATE_SCREENS.md`

### Navigate between screens
Add route to `Navigation/AppRouter.swift` (create if needed)

### Reuse a component
Place in `UI/Components/` and import it

### Handle errors
See error handling pattern in template ViewModel

---

## Build & Test

```bash
# Open in Xcode
open TheRecruitingCompass.xcodeproj

# Or from command line
xcodebuild build -scheme TheRecruitingCompass

# In Xcode: Cmd+R to run simulator
```

---

## Notes

- Template is in `_ScreenTemplate/` - copy it for every new screen
- Follow the naming convention: `FeatureNameView`, `FeatureNameViewModel`
- All ViewModels must be `@MainActor` for thread safety
- Services never touch UI - keep them pure

---

Happy coding! 🚀
