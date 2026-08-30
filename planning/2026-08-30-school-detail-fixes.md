# School Detail Page Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 5 UX issues on the School Detail page: Send Email → Quick Comm, auto-save focus dismissal, Log Interaction pre-selects school, See All Coaches cache-bust, and Add Coach from school detail.

**Architecture:** Each fix is independent — touches different closures/components on SchoolDetailView. Tasks 1 and 3 add optional parameters to existing views/viewmodels. Task 5 adds a new navigation destination to SchoolDetailView + an "Add Coach" button to SchoolCoachesPanel's empty state.

**Tech Stack:** SwiftUI, @Observable ViewModels, NavigationStack/NavigationPath

**Spec:** User-reported bugs (no formal spec)

## Global Constraints

- Xcode 26.5, iOS 26.5 SDK, iPhone 17 simulator
- All ViewModels `@Observable @MainActor` with `nonisolated deinit {}`
- Build from `TheRecruitingCompass/` subdir
- Source at double-nested `TheRecruitingCompass/TheRecruitingCompass/Features/...`
- `PBXFileSystemSynchronizedRootGroup` — no xcodeproj edits needed for new files
- Accessibility: all interactive elements need `.accessibilityLabel()`, 44pt min tap targets
- Line length ≤120 (SwiftLint)

---

### Task 1: Send Email → Quick Comm with coach picker

**Problem:** "Send Email" quick action silently opens `mailto:` for first coach. No coach picker, no Quick Comm, no interaction logging, silent no-op when no coaches/email.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/SchoolDetailView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/Components/SchoolQuickActions.swift`

**Interfaces:**
- Consumes: `QuickCommunicationContext(coach:schoolName:)`, `QuickCommunicationView(context:)`
- Produces: `SchoolQuickActions` gains `coachCount: Int` to show badge/context. SchoolDetailView presents Quick Comm sheet.

- [ ] **Step 1: Update SchoolQuickActions to accept coach count for empty-state feedback**

In `SchoolQuickActions.swift`, add a `coachCount` param and rename `onSendEmail` → `onQuickComm` to reflect new behavior. When `coachCount == 0`, show disabled state on the button:

```swift
struct SchoolQuickActions: View {
  let onLogInteraction: () -> Void
  let onQuickComm: () -> Void
  let onManageCoaches: () -> Void
  let coachCount: Int

  // ... body unchanged except the Send Email button:

  QuickActionButton(
    icon: "envelope.badge.fill",
    title: String(localized: "Quick Comm"),
    gradient: LinearGradient(
      colors: [Color.successGreen, Color.successGreen.opacity(0.7)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    ),
    action: onQuickComm,
    isDisabled: coachCount == 0
  )
```

Add `isDisabled` param to `QuickActionButton`:

```swift
private struct QuickActionButton: View {
  let icon: String
  let title: String
  let gradient: LinearGradient
  let action: () -> Void
  var isDisabled: Bool = false

  // In body:
  Button(action: action) { /* existing */ }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.4 : 1.0)
    // ... existing modifiers
```

- [ ] **Step 2: Add Quick Comm sheet presentation to SchoolDetailView**

In `SchoolDetailView.swift`, add state for coach picker + Quick Comm context:

```swift
@State private var quickCommunicationContext: QuickCommunicationContext?
@State private var showCoachPickerForQuickComm = false
```

Replace the `onSendEmail` closure (lines 175–180):

```swift
onQuickComm: {
  let coaches = viewModel.coaches
  if coaches.count == 1, let coach = coaches.first {
    quickCommunicationContext = QuickCommunicationContext(
      coach: coach,
      schoolName: school.name
    )
  } else if coaches.count > 1 {
    showCoachPickerForQuickComm = true
  }
  // coachCount == 0 → button disabled, won't fire
},
coachCount: viewModel.coaches.count
```

Add the sheet modifiers after the existing `.sheet` chain (after the `.toast` at end of `detailContent`):

```swift
.sheet(item: $quickCommunicationContext) { context in
  QuickCommunicationView(context: context)
}
.confirmationDialog(
  "Select Coach",
  isPresented: $showCoachPickerForQuickComm,
  titleVisibility: .visible
) {
  ForEach(viewModel.coaches) { coach in
    Button("\(coach.firstName) \(coach.lastName)") {
      quickCommunicationContext = QuickCommunicationContext(
        coach: coach,
        schoolName: school.name
      )
    }
  }
  Button("Cancel", role: .cancel) {}
}
```

- [ ] **Step 3: Update preview**

Update `SchoolQuickActions` preview:

```swift
#Preview {
  SchoolQuickActions(
    onLogInteraction: {},
    onQuickComm: {},
    onManageCoaches: {},
    coachCount: 2
  )
  .padding()
}
```

- [ ] **Step 4: Build verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(schools): replace Send Email with Quick Comm coach picker"
```

---

### Task 2: Dismiss field focus after auto-save

**Problem:** `SchoolNotesSection` TextEditor stays focused after auto-save on blur, causing auto-scroll disruptions when navigating the page.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/Components/SchoolNotesSection.swift`

**Interfaces:**
- No changes to public API.

- [ ] **Step 1: Add toolbar Done button to dismiss keyboard**

The real problem is TextEditor stays focused (keyboard up) even after typing stops. iOS TextEditor has no native "done" — add a toolbar button. The `onBlur` already fires on focus loss, so the fix is giving users a way to dismiss focus:

```swift
struct SchoolNotesSection: View {
  let title: String
  @Binding var notes: String
  let onBlur: () async -> Void

  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()
      }

      TextEditor(text: $notes)
        .frame(minHeight: 120)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .focused($isFocused)
        .toolbar {
          ToolbarItemGroup(placement: .keyboard) {
            if isFocused {
              Spacer()
              Button("Done") {
                isFocused = false
              }
              .accessibilityLabel(String(localized: "Dismiss keyboard"))
            }
          }
        }
        .accessibilityIdentifier(
          "\(title.lowercased().replacing(" ", with: "-"))-text-editor"
        )
        .accessibilityLabel(String(localized: "\(title) text editor"))
        .accessibilityHint("Enter your \(title.lowercased())")
        .accessibilityValue(notes.isEmpty ? "Empty" : notes)
        .onChange(of: isFocused) { _, focused in
          if !focused {
            Task { await onBlur() }
          }
        }
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(.rect(cornerRadius: 12))
  }
}
```

**Note:** Multiple `SchoolNotesSection` instances on one page share the keyboard toolbar — SwiftUI merges `ToolbarItemGroup(placement: .keyboard)` from the focused view. The `if isFocused` guard ensures only the active one shows "Done". This is standard SwiftUI behavior.

- [ ] **Step 2: Build verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix(schools): add Done button to dismiss notes keyboard after auto-save"
```

---

### Task 3: Log Interaction pre-selects school

**Problem:** Tapping "Log Interaction" from school detail opens AddInteractionView without pre-selecting the school — user must pick it manually even though context is obvious.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Views/AddInteractionView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/ViewModels/AddInteractionViewModel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/SchoolDetailView.swift`

**Interfaces:**
- Produces: `AddInteractionView.init` gains optional `preselectedSchoolId: String?` param; `AddInteractionViewModel.init` gains same.

- [ ] **Step 1: Add `preselectedSchoolId` to AddInteractionViewModel**

In `AddInteractionViewModel.swift`, add an optional school ID that gets applied after `loadFormData()`:

```swift
// In properties section, after userId:
private let preselectedSchoolId: String?

// Update init:
init(
  interactionsService: any InteractionsManaging,
  familyUnitId: String,
  userId: String,
  preselectedSchoolId: String? = nil
) {
  self.interactionsService = interactionsService
  self.familyUnitId = familyUnitId
  self.userId = userId
  self.preselectedSchoolId = preselectedSchoolId
}

// At end of loadFormData(), after the do block's success path (after logger.info line):
if let preselectedSchoolId, schools.contains(where: { $0.id == preselectedSchoolId }) {
  formState.schoolId = preselectedSchoolId
  logger.debug("Pre-selected school: \(preselectedSchoolId)")
}
```

- [ ] **Step 2: Add `preselectedSchoolId` to AddInteractionView init**

In `AddInteractionView.swift`, update init:

```swift
init(
  interactionsService: InteractionsManaging,
  familyUnitId: String,
  userId: String,
  preselectedSchoolId: String? = nil,
  onLogged: @escaping (String?) -> Void = { _ in }
) {
  _viewModel = State(initialValue: AddInteractionViewModel(
    interactionsService: interactionsService,
    familyUnitId: familyUnitId,
    userId: userId,
    preselectedSchoolId: preselectedSchoolId
  ))
  self.onLogged = onLogged
}
```

- [ ] **Step 3: Pass schoolId from SchoolDetailView**

In `SchoolDetailView.swift`, update the `AddInteractionView` construction (around line 299):

```swift
AddInteractionView(
  interactionsService: InteractionsServiceImpl(supabaseManager: .shared),
  familyUnitId: familyUnitId,
  userId: userId,
  preselectedSchoolId: schoolId,
  onLogged: { message in
    Task { await viewModel.loadSchool() }
    if let message {
      advanceToastMessage = message
      showAdvanceToast = true
    }
  }
)
```

- [ ] **Step 4: Build verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(interactions): pre-select school when logging from school detail"
```

---

### Task 4: See All Coaches cache invalidation

**Problem:** "See All" / "Manage Coaches" sometimes shows a stale cached view — navigating shows a previously viewed coach detail instead of the filtered list.

**Root cause:** `filterCoachesBySchool` in MainTabView resets `coachesPath = NavigationPath()` (clearing nav stack) and sets `coachesPrefilterSchoolId`. But `CoachesListView` consumes the prefilter in `.onAppear` — if the Coaches tab was already the selected tab, `.onAppear` won't re-fire. The `.onChange(of: prefilterSchoolId)` handler exists but fires AFTER the view reappears, potentially causing a flash of the old state.

Also, `coachesPath = NavigationPath()` creates a NEW path instance, but `CoachesListView` uses its own `@State private var navigationPath` — the external path is only synced via `onChange(of: externalNavigationPath)`, and setting `coachesPath` to empty doesn't trigger that `onChange` if it was already empty.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift`

**Interfaces:**
- No public API changes.

- [ ] **Step 1: Force coaches reload on filter**

The simplest fix: give `CoachesListView` a fresh identity when the school filter changes, forcing SwiftUI to recreate it. In `MainTabView.swift`, add an ID counter:

```swift
@State private var coachesViewId = 0
```

Update the `filterCoachesBySchool` environment closure:

```swift
.environment(\.filterCoachesBySchool, { schoolId in
  coachesPrefilterSchoolId = schoolId
  coachesPath = NavigationPath()
  coachesViewId += 1
  selectedTab = .coaches
})
```

Add `.id()` to the CoachesListView in the Tab:

```swift
Tab("Coaches", systemImage: "person.2", value: AppTab.coaches) {
  CoachesListView(prefilterSchoolId: $coachesPrefilterSchoolId, navigationPath: $coachesPath)
    .id(coachesViewId)
}
```

This forces a full recreate of the CoachesListView, which re-fires `.task` → `loadCoaches()` + `consumePrefilterSchool()`.

- [ ] **Step 2: Build verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix(coaches): force list refresh when navigating from school detail"
```

---

### Task 5: Add Coach button on school detail (empty state + panel header)

**Problem:** No way to add a coach from the school detail page. When no coaches exist, the empty state just says "use manage coaches" — should have an inline Add Coach button that pre-populates the school.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/Components/SchoolCoachesPanel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/SchoolDetailView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/AddCoachView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/AddCoachViewModel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Models/CoachFormState.swift`

**Interfaces:**
- Produces: `SchoolCoachesPanel` gains `onAddCoach: (() -> Void)?`. `AddCoachView` + `AddCoachViewModel` gain optional `preselectedSchoolId: String?` that auto-selects the school and locks the picker.

- [ ] **Step 1: Add preselectedSchoolId to AddCoachViewModel**

In `AddCoachViewModel.swift`:

```swift
// Add property:
private let preselectedSchoolId: String?

// Update both inits:
nonisolated init(
  coachesService: CoachesManaging,
  familyUnitId: String,
  userId: String,
  announcer: AccessibilityAnnouncing,
  preselectedSchoolId: String? = nil
) {
  self.coachesService = coachesService
  self.familyUnitId = familyUnitId
  self.userId = userId
  self.announcer = announcer
  self.preselectedSchoolId = preselectedSchoolId
}

convenience init(
  coachesService: CoachesManaging,
  familyUnitId: String,
  userId: String,
  preselectedSchoolId: String? = nil
) {
  self.init(
    coachesService: coachesService,
    familyUnitId: familyUnitId,
    userId: userId,
    announcer: AccessibilityAnnouncer(),
    preselectedSchoolId: preselectedSchoolId
  )
}

// Add computed property:
var isSchoolLocked: Bool { preselectedSchoolId != nil }
```

At the end of `loadSchools()`, after `schools = try await ...`:

```swift
if let preselectedSchoolId,
   schools.contains(where: { $0.id == preselectedSchoolId }) {
  formState.selectedSchoolId = preselectedSchoolId
  logger.debug("Pre-selected school: \(preselectedSchoolId)")
}
```

- [ ] **Step 2: Add preselectedSchoolId to AddCoachView**

In `AddCoachView.swift`, update init:

```swift
init(
  coachesService: CoachesManaging,
  familyUnitId: String,
  userId: String,
  navigationPath: Binding<NavigationPath>,
  preselectedSchoolId: String? = nil
) {
  _viewModel = State(initialValue: AddCoachViewModel(
    coachesService: coachesService,
    familyUnitId: familyUnitId,
    userId: userId,
    preselectedSchoolId: preselectedSchoolId
  ))
  _navigationPath = navigationPath
}
```

In `schoolSelectionSection`, disable the picker when school is locked:

```swift
SchoolPicker(
  selectedSchoolId: $viewModel.formState.selectedSchoolId,
  schools: viewModel.schools,
  isDisabled: viewModel.isSubmitting || viewModel.isSchoolLocked
)
```

- [ ] **Step 3: Add onAddCoach to SchoolCoachesPanel**

In `SchoolCoachesPanel.swift`, add the callback and a "+" button in the header + update the empty state:

```swift
struct SchoolCoachesPanel: View {
  let coaches: [Coach]
  let isLoading: Bool
  let onSeeAll: () -> Void
  var onAddCoach: (() -> Void)?  // new, optional

  // In the HStack header, before Spacer():
  // (keep existing)

  // After Spacer(), before hasMoreCoaches check, add:
  if let onAddCoach {
    Button(action: onAddCoach) {
      Image(systemName: "plus.circle.fill")
        .font(.title3)
        .foregroundStyle(Color.accentBlue)
    }
    .accessibilityLabel(String(localized: "Add coach"))
    .accessibilityHint("Add a new coach to this school")
  }
```

Update `CoachesEmptyState` to accept an add action:

```swift
private struct CoachesEmptyState: View {
  var onAddCoach: (() -> Void)?

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "person.crop.circle.badge.questionmark")
        .font(.largeTitle)
        .imageScale(.large)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No Coaches Added")
        .font(.headline)
        .foregroundStyle(.secondary)

      Text("Add coaches to track your recruiting contacts")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)

      if let onAddCoach {
        Button(action: onAddCoach) {
          Label("Add Coach", systemImage: "plus")
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .accessibilityLabel(String(localized: "Add a coach to this school"))
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "No coaches added"))
    .accessibilityHint("Use the add coach button to add recruiting contacts")
  }
}
```

Wire it in the panel body:

```swift
} else if coaches.isEmpty {
  CoachesEmptyState(onAddCoach: onAddCoach)
} else {
```

- [ ] **Step 4: Add navigation destination for AddCoach in SchoolDetailView**

In `SchoolDetailView.swift`, extend `NavigationDestination` enum:

```swift
private enum NavigationDestination: Hashable {
  case addInteraction(schoolId: String)
  case addCoach(schoolId: String)
}
```

Add state for an inline navigation path (or reuse `navigationDestination`):

Wire the `SchoolCoachesPanel`:

```swift
SchoolCoachesPanel(
  coaches: viewModel.coaches,
  isLoading: viewModel.isLoadingCoaches,
  onSeeAll: {
    filterCoachesBySchool(schoolId)
  },
  onAddCoach: {
    navigationDestination = .addCoach(schoolId: schoolId)
  }
)
```

Add the case to `navigationDestination(item:)`:

```swift
case .addCoach(let schoolId):
  if let familyUnitId = familyManager.familyUnitId,
     let userId = viewModel.currentUserId {
    AddCoachView(
      coachesService: CoachesServiceImpl(supabaseManager: .shared),
      familyUnitId: familyUnitId,
      userId: userId,
      navigationPath: .constant(NavigationPath()),
      preselectedSchoolId: schoolId
    )
  } else {
    ContentUnavailableView(
      "Sign In Required",
      systemImage: "person.crop.circle.badge.xmark"
    )
  }
```

After a coach is added, reload the coaches list on the school detail. In `AddCoachView`, when `submitCoach()` succeeds, it navigates to coach detail — from school detail context, we should instead dismiss and reload. This works because `AddCoachView` already invalidates the coaches cache (`InMemoryCache.shared.remove(forKey: ListCacheKeys.coaches(...))`), and `SchoolDetailView` reloads coaches on appear. But we need to ensure it reloads — add `.onDisappear` or better, rely on the existing `.task` reload pattern.

Actually: the `AddCoachView.submitCoach()` calls `navigationPath.append(CoachDestination.detail(newCoach.id))` — when `navigationPath` is `.constant(NavigationPath())`, this is a no-op. The new coach IS created + cache invalidated. When the user taps Back, they return to school detail which should reload. To ensure reload, add an `onDismiss` handler or an `onAppear` reload in the coaches panel.

Add a simple reload trigger — in `SchoolDetailView`, wrap the `SchoolCoachesPanel` section with:

```swift
SchoolCoachesPanel(...)
  .onAppear { Task { await viewModel.loadCoaches() } }
```

Wait — `loadCoaches()` may not exist as a standalone. Check if coaches are loaded as part of `loadSchool()`. If they are, `.task { await viewModel.loadSchool() }` at top already covers initial load. For re-triggering on return from AddCoach, we need the nav destination pop to trigger a reload.

Simpler: use `.onChange(of: navigationDestination)` — when it goes back to nil (user navigated back), reload:

```swift
.onChange(of: navigationDestination) { old, new in
  if old != nil && new == nil {
    Task { await viewModel.loadSchool() }
  }
}
```

- [ ] **Step 5: Update previews**

Update `SchoolCoachesPanel` previews to pass `onAddCoach`:

```swift
#Preview("Empty") {
  SchoolCoachesPanel(
    coaches: [],
    isLoading: false,
    onSeeAll: {},
    onAddCoach: {}
  )
  .padding()
}
```

- [ ] **Step 6: Build verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(schools): add coach from school detail with school pre-selected"
```

---

### Task 6: Final build + test verification

- [ ] **Step 1: Full build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | tail -5
```

- [ ] **Step 2: Run affected unit tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests 2>&1 | tail -20
```

- [ ] **Step 3: Verify no regressions**

Check test exit code. If failures, investigate whether tests are stale (spec changed) or code is wrong.
