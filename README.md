# TheRecruitingCompass iOS (Fresh Start)

Clean iOS app built from scratch with a reusable screen template system.

## Quick Start

### Your Workflow

1. **Look at web page** → What data? What buttons/actions?
2. **Copy template** → `UI/Screens/_ScreenTemplate/` → Rename folder
3. **Rename 3 files** → Follow `HOW_TO_CREATE_SCREENS.md`
4. **Build** → Cmd+R

That's it. New screen in 10 minutes.

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
