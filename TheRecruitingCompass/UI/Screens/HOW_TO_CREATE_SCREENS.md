# How to Create a New Screen (Web → iOS)

## Quick Workflow

1. **Look at web page** → Understand what data it displays and what actions it supports
2. **Copy template folder** → `_ScreenTemplate/` → Rename to your feature (e.g., `Schools/`)
3. **Rename files** → `ExampleScreen*` → `YourFeatureName*`
4. **Update 3 files** → ViewModel, View, Service
5. **Done!** → Build and test

---

## Step-by-Step Example: Creating a "Schools List" Screen

### 1. Copy Template
```bash
cp -r UI/Screens/_ScreenTemplate UI/Screens/Schools
```

### 2. Rename Files
```bash
mv Schools/ExampleScreenViewModel.swift Schools/SchoolsListViewModel.swift
mv Schools/ExampleScreenView.swift Schools/SchoolsListView.swift
```

### 3. Update ViewModel

**File:** `Schools/SchoolsListViewModel.swift`

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

**What's happening:**
- `@Published` variables update the UI automatically
- `@MainActor` ensures thread-safe UI updates
- `loadSchools()` calls the service and updates state

---

### 4. Update View

**File:** `Schools/SchoolsListView.swift`

```swift
struct SchoolsListView: View {
    @StateObject var viewModel = SchoolsListViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error, onRetry: {
                    Task { await viewModel.loadSchools() }
                })
            } else if viewModel.schools.isEmpty {
                EmptyStateView(message: "No schools yet")
            } else {
                List(viewModel.schools) { school in
                    NavigationLink(destination: SchoolDetailView(schoolId: school.id)) {
                        SchoolRow(school: school)
                    }
                }
            }
        }
        .navigationTitle("Schools")
        .task { await viewModel.loadSchools() }
    }
}
```

**What's happening:**
- Shows loading state while fetching
- Shows error if something goes wrong
- Shows empty state if no data
- Shows list of schools
- `@StateObject` creates one ViewModel instance per view

---

### 5. Update Service

**File:** `Data/Services/SchoolsService.swift`

```swift
final class SchoolsService {

    func fetchSchools() async throws -> [School] {
        let url = URL(string: "https://api.example.com/schools")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let schools = try JSONDecoder().decode([School].self, from: data)
        return schools
    }

    func createSchool(_ school: School) async throws {
        // POST request logic
    }
}
```

**What's happening:**
- Pure async/await methods
- No `@Published` or `ObservableObject`
- Returns data to ViewModel
- ViewModel handles state management

---

## The Pattern

```
Web Page
  ↓
Understand: What data? What actions?
  ↓
ViewModel: Manages state, calls service
  ↓
View: Displays state, calls ViewModel methods
  ↓
Service: Fetches data, no UI logic
```

---

## File Structure After Creating a Screen

```
UI/Screens/Schools/
  ├── SchoolsListViewModel.swift
  ├── SchoolsListView.swift
  ├── SchoolDetailViewModel.swift
  └── SchoolDetailView.swift

Data/Services/
  └── SchoolsService.swift

Data/Models/
  └── School.swift
```

---

## Common Patterns

### Search/Filter
```swift
@Published var searchText = ""

var filteredSchools: [School] {
    searchText.isEmpty
        ? schools
        : schools.filter { $0.name.contains(searchText) }
}
```

### Navigation
```swift
@Published var selectedSchool: School?
@Published var showDetail = false

NavigationLink(isActive: $showDetail) {
    SchoolDetailView(school: selectedSchool!)
}
```

### Async Actions
```swift
func deleteSchool(_ id: UUID) async {
    do {
        try await schoolsService.deleteSchool(id)
        schools.removeAll { $0.id == id }
    } catch {
        errorMessage = "Failed to delete"
    }
}
```

---

## Checklist for New Screen

- [ ] Renamed template files to match feature
- [ ] Updated ViewModel with your data types
- [ ] Updated View to display your data
- [ ] Created/updated Service with API calls
- [ ] Added Model if needed
- [ ] Preview compiles
- [ ] Added to navigation (router)

Done! Ready to test.
