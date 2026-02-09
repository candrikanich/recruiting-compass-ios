# Coaches List Navigation - Implementation Plan

**Date:** February 8, 2026
**Priority:** HIGH (Blocking MVP)
**Estimated Time:** 2-3 hours
**Complexity:** Medium

---

## Overview

Implement navigation to coach detail view and add coach view to complete the Coaches List feature per the spec. This establishes the navigation pattern for other list features (Schools, Interactions).

---

## Current State

✅ **Working:**
- CoachesListView displays all coaches
- Search, filter, sort working correctly
- Delete with cascade fallback working
- Communication actions working
- All 65+ tests passing

❌ **Missing:**
- Tap coach card → Coach detail view
- "Add Coach" button → Add coach view
- CoachDestination navigation model
- CoachDetailView
- AddCoachView

---

## Implementation Steps

### Step 1: Create Navigation Model (15 min)

**File:** `Features/Coaches/Models/CoachDestination.swift`

```swift
import Foundation

enum CoachDestination: Hashable {
  case detail(String)  // Coach ID
  case add
}
```

**Why:**
- SwiftUI NavigationStack requires Hashable destination types
- Enum allows different destinations from same list
- Pass coach ID for detail view (lazy loading)

---

### Step 2: Create Placeholder CoachDetailView (30 min)

**File:** `Features/Coaches/Views/CoachDetailView.swift`

```swift
import SwiftUI

struct CoachDetailView: View {
  let coachId: String
  @StateObject private var viewModel: CoachDetailViewModel

  init(coachId: String) {
    self.coachId = coachId
    _viewModel = StateObject(wrappedValue: CoachDetailViewModel(coachId: coachId))
  }

  var body: some View {
    ScrollView {
      if viewModel.isLoading {
        loadingView
      } else if let coach = viewModel.coach {
        detailContent(coach: coach)
      } else if let error = viewModel.errorMessage {
        errorView(message: error)
      }
    }
    .navigationTitle("Coach Details")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await viewModel.loadCoach()
    }
  }

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .accessibilityLabel("Loading coach details")
      Text("Loading...")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func detailContent(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      headerSection(coach: coach)
      contactInfoSection(coach: coach)
      statisticsSection(coach: coach)
      notesSection(coach: coach)
      actionsSection(coach: coach)
    }
    .padding()
  }

  private func headerSection(coach: Coach) -> some View {
    VStack(spacing: 16) {
      // Large initials circle
      Text(coach.initials)
        .font(.largeTitle.bold())
        .foregroundStyle(.white)
        .frame(width: 100, height: 100)
        .background(
          LinearGradient(
            colors: [.blueGradientStart, Color(hex: "7C3AED")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .clipShape(Circle())
        .accessibilityHidden(true)

      Text(coach.fullName)
        .font(.title2.bold())
        .accessibilityAddTraits(.isHeader)

      Text(coach.role.displayName)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let school = viewModel.school {
        Text(school.name)
          .font(.subheadline)
          .foregroundStyle(Color.accentBlue)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func contactInfoSection(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "Contact Information")

      if let email = coach.email {
        contactRow(icon: "envelope", label: "Email", value: email)
      }

      if let phone = coach.phone {
        contactRow(icon: "phone", label: "Phone", value: phone)
      }

      if let twitter = coach.twitterHandle {
        contactRow(icon: "at", label: "Twitter", value: twitter)
      }

      if let instagram = coach.instagramHandle {
        contactRow(icon: "camera", label: "Instagram", value: instagram)
      }
    }
  }

  private func statisticsSection(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "Statistics")

      ResponsivenessBar(score: coach.responsivenessScore)

      if let lastContact = coach.lastContactDateParsed {
        HStack {
          Image(systemName: "clock")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
          Text("Last contacted \(lastContact, style: .relative) ago")
            .font(.subheadline)
        }
      }
    }
  }

  private func notesSection(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "Notes")

      if let notes = coach.notes, !notes.isEmpty {
        Text(notes)
          .font(.body)
          .foregroundStyle(.primary)
      } else {
        Text("No notes")
          .font(.body)
          .foregroundStyle(.secondary)
          .italic()
      }
    }
  }

  private func actionsSection(coach: Coach) -> some View {
    VStack(spacing: 12) {
      Button {
        // TODO: Edit coach
      } label: {
        HStack {
          Image(systemName: "pencil")
          Text("Edit Coach")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .foregroundStyle(.white)
        .background(Color.accentBlue)
        .cornerRadius(8)
      }
      .accessibilityLabel("Edit coach details")

      Button(role: .destructive) {
        // TODO: Delete coach
      } label: {
        HStack {
          Image(systemName: "trash")
          Text("Delete Coach")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .foregroundStyle(.white)
        .background(Color.errorRed)
        .cornerRadius(8)
      }
      .accessibilityLabel("Delete coach")
      .accessibilityHint("Shows delete confirmation")
    }
  }

  private func sectionHeader(title: String) -> some View {
    Text(title)
      .font(.headline)
      .foregroundStyle(.primary)
      .accessibilityAddTraits(.isHeader)
  }

  private func contactRow(icon: String, label: String, value: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.body)
        .foregroundStyle(.secondary)
        .frame(width: 24)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.body)
      }
    }
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(Color.errorRed)
      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}

#Preview {
  NavigationStack {
    CoachDetailView(coachId: "test-id")
  }
}
```

**Why:**
- Read-only detail view for MVP
- Shows all coach information in organized sections
- Matches iOS design patterns (large header, grouped sections)
- Accessibility labels on all sections
- Edit/Delete buttons for future implementation

---

### Step 3: Create CoachDetailViewModel (30 min)

**File:** `Features/Coaches/ViewModels/CoachDetailViewModel.swift`

```swift
import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CoachDetailViewModel")

@MainActor
final class CoachDetailViewModel: ObservableObject {
  @Published var coach: Coach?
  @Published var school: School?
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let coachId: String
  private let coachesService: any CoachesManaging

  nonisolated init(
    coachId: String,
    coachesService: any CoachesManaging = CoachesServiceImpl(supabaseManager: .shared)
  ) {
    self.coachId = coachId
    self.coachesService = coachesService
  }

  func loadCoach() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      // TODO: Implement fetchCoach(id:) in service
      // For now, this will fail gracefully
      errorMessage = "Coach detail loading not yet implemented"
      logger.warning("Coach detail loading not yet implemented")
    } catch {
      logger.error("Failed to load coach: \(error.localizedDescription)")
      errorMessage = "Failed to load coach details"
    }
  }
}
```

**Why:**
- Follows same pattern as CoachesListViewModel
- Protocol-based DI for testing
- Proper error handling
- Placeholder for future fetch implementation

---

### Step 4: Create Placeholder AddCoachView (20 min)

**File:** `Features/Coaches/Views/AddCoachView.swift`

```swift
import SwiftUI

struct AddCoachView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          Image(systemName: "person.fill.badge.plus")
            .font(.system(size: 80))
            .foregroundStyle(Color.accentBlue.gradient)
            .padding(.top, 40)

          Text("Add Coach")
            .font(.title2.bold())

          Text("This feature is coming soon. You'll be able to add new coaches to your tracked schools.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
      }
      .navigationTitle("Add Coach")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  AddCoachView()
}
```

**Why:**
- Simple placeholder with "Coming Soon" message
- Proper navigation structure for future form implementation
- Dismiss handler for sheet presentation
- Accessible layout

---

### Step 5: Update CoachesListView Navigation (30 min)

**File:** `Features/Coaches/Views/CoachesListView.swift`

**Changes:**

```swift
// Add @State for sheet presentation
@State private var showAddCoach = false

// Replace coachCards section
private var coachCards: some View {
  ForEach(viewModel.filteredCoaches) { coach in
    NavigationLink(value: CoachDestination.detail(coach.id)) {
      CoachCardView(
        coach: coach,
        schoolName: viewModel.schoolName(for: coach.schoolId),
        onDelete: { viewModel.confirmDelete(coach) }
      )
      .padding(.horizontal, 16)
      .padding(.vertical, 4)
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// Add toolbar to body
.toolbar {
  ToolbarItem(placement: .navigationBarTrailing) {
    Button {
      showAddCoach = true
    } label: {
      Image(systemName: "plus")
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel("Add new coach")
    .accessibilityHint("Opens form to add a new coach")
  }
}

// Add navigation destination
.navigationDestination(for: CoachDestination.self) { destination in
  switch destination {
  case .detail(let coachId):
    CoachDetailView(coachId: coachId)
  case .add:
    AddCoachView()
  }
}

// Add sheet for AddCoachView
.sheet(isPresented: $showAddCoach) {
  AddCoachView()
}
```

**Why:**
- NavigationLink wraps CoachCardView for tap navigation
- PlainButtonStyle prevents default link styling
- Toolbar button follows iOS patterns (plus icon in trailing position)
- Sheet presentation for Add Coach (modal form pattern)
- .navigationDestination handles both detail and add destinations

---

### Step 6: Update CoachCardView for Navigation (15 min)

**File:** `Features/Coaches/Components/CoachCardView.swift`

**Changes:**

```swift
// Remove chevron.right icon from actionsSection
// NavigationLink will provide disclosure indicator automatically

// Update accessibility label to indicate tappable
.accessibilityLabel("\(coach.fullName), \(coach.role.displayName) at \(schoolName), responsiveness \(Int(coach.responsivenessScore))%")
.accessibilityHint("Double tap to view coach details")
```

**Why:**
- NavigationLink provides automatic disclosure indicator
- Accessibility hint informs users the card is tappable
- Reduces visual clutter

---

### Step 7: Add Swipe-to-Delete (Optional - 15 min)

**File:** `Features/Coaches/Views/CoachesListView.swift`

**Changes:**

```swift
NavigationLink(value: CoachDestination.detail(coach.id)) {
  CoachCardView(
    coach: coach,
    schoolName: viewModel.schoolName(for: coach.schoolId),
    onDelete: { viewModel.confirmDelete(coach) }
  )
  .padding(.horizontal, 16)
  .padding(.vertical, 4)
}
.buttonStyle(PlainButtonStyle())
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
  Button(role: .destructive) {
    viewModel.confirmDelete(coach)
  } label: {
    Label("Delete", systemImage: "trash")
  }
}
```

**Why:**
- Provides alternative delete method (spec requirement)
- allowsFullSwipe: false prevents accidental deletion
- Label provides both icon and text for clarity

---

### Step 8: Testing (30 min)

**Test Cases:**

1. **Navigation to Detail:**
   - Tap coach card → navigates to CoachDetailView
   - Back button returns to list
   - Navigation title correct
   - Loading state shown while fetching

2. **Add Coach Button:**
   - Tap + button → shows AddCoachView sheet
   - Cancel button dismisses sheet
   - Sheet presentation/dismissal smooth

3. **Swipe to Delete:**
   - Swipe left on card → shows delete button
   - Tap delete → shows confirmation dialog
   - Swipe doesn't trigger full swipe delete

4. **Accessibility:**
   - VoiceOver announces card is tappable
   - Add coach button has proper label
   - Detail view sections have header traits
   - All buttons have labels and hints

**Manual Testing Checklist:**
- [ ] Tap card navigates to detail
- [ ] + button opens add sheet
- [ ] Cancel dismisses add sheet
- [ ] Back button returns from detail
- [ ] Swipe-to-delete works
- [ ] VoiceOver announces all actions correctly
- [ ] Dynamic Type scales properly in detail view
- [ ] All tests still pass (should be 538+)

---

## File Structure Summary

**New Files (4):**
```
Features/Coaches/
  Models/
    CoachDestination.swift          # Navigation model
  Views/
    CoachDetailView.swift           # Detail screen (read-only)
    AddCoachView.swift              # Add screen (placeholder)
  ViewModels/
    CoachDetailViewModel.swift     # Detail view state
```

**Modified Files (2):**
```
Features/Coaches/
  Views/
    CoachesListView.swift           # Add navigation + toolbar
  Components/
    CoachCardView.swift             # Remove chevron, add hint
```

---

## Future Enhancements (Not in This Plan)

1. **Full CoachDetailView:**
   - Edit mode with form fields
   - Save/cancel buttons
   - Validation
   - Update coach API call

2. **Full AddCoachView:**
   - Form with all coach fields
   - School picker
   - Role picker
   - Validation
   - Create coach API call

3. **Toast Component:**
   - Success messages after delete
   - "Coach deleted" vs "Coach and X interactions deleted"
   - App-wide toast manager

4. **CoachesService Enhancement:**
   - fetchCoach(id:) method
   - updateCoach(id:, data:) method
   - createCoach(data:) method

---

## Success Criteria

✅ **Navigation Working:**
- Tap coach card → CoachDetailView loads
- + button → AddCoachView sheet appears
- Back/Cancel navigation works smoothly

✅ **UI Polish:**
- No visual glitches or layout issues
- Smooth transitions
- Proper loading states

✅ **Accessibility:**
- All new screens have proper labels
- VoiceOver navigation works correctly
- Dynamic Type support in detail view

✅ **Tests:**
- All existing tests still pass
- No new warnings or errors
- Clean build (0 errors, 0 warnings)

---

## Timeline

**Total Time:** 2-3 hours

| Step | Task | Time | Priority |
|------|------|------|----------|
| 1 | Create CoachDestination model | 15 min | HIGH |
| 2 | Create CoachDetailView | 30 min | HIGH |
| 3 | Create CoachDetailViewModel | 30 min | HIGH |
| 4 | Create AddCoachView | 20 min | HIGH |
| 5 | Update CoachesListView | 30 min | HIGH |
| 6 | Update CoachCardView | 15 min | HIGH |
| 7 | Add swipe-to-delete | 15 min | MEDIUM |
| 8 | Testing | 30 min | HIGH |
| **Total** | | **2h 45min** | |

---

## Dependencies

**Required:**
- Existing CoachesListView ✅
- Existing CoachCardView ✅
- Existing CoachesListViewModel ✅
- SwiftUI NavigationStack ✅

**Optional:**
- fetchCoach(id:) API (can build without it)
- createCoach(data:) API (can build without it)

---

## Risk Assessment

🟢 **Low Risk:**
- Well-established SwiftUI navigation patterns
- No breaking changes to existing code
- All changes are additive
- Tests provide safety net

⚠️ **Considerations:**
- Detail view won't load data until fetchCoach API is implemented
- Add coach is placeholder only
- Users can navigate but not edit/create yet

---

## Approval

**Ready to Implement:** ✅ Yes

**Reviewed by:** Claude (Implementation Planner)
**Date:** February 8, 2026
