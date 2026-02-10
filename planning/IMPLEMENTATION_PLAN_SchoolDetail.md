# Implementation Plan: School Detail View (Phase 3)

**Created:** February 10, 2026
**Spec:** iOS_SPEC_Phase3_SchoolDetail.md
**Estimated Time:** 4-5 days
**Complexity:** High

---

## Executive Summary

This plan implements the School Detail view, the most complex single-page view in the app. It combines viewing, editing, external API integration (College Scorecard), fit score calculation, status management with history, and coach contact actions into a single scrollable detail view.

**Strategy:** Implement in 4 phases to manage complexity and enable incremental testing.

---

## Current State Analysis

### ✅ What We Have

**Models:**
- `School` model with most fields (missing: `privateNotes` dictionary)
- `Coach` model (complete)
- `AcademicInfo` nested struct (missing: several fields from spec)
- `SchoolStatus` as String (needs conversion to enum)
- `SchoolSize` enum (complete)

**Services:**
- `SchoolsManaging` protocol with basic CRUD
- `CoachesManaging` protocol (complete)
- `SchoolsServiceImpl` (basic implementation)

**Views/Components:**
- `SchoolCardView` (list view)
- `CoachCardView` (reusable)
- Navigation infrastructure with `SchoolDestination`

**Patterns Established:**
- MVVM with `@MainActor` ViewModels
- Protocol-based DI for services
- Private notes as `[userId: note]` dictionary
- Cascade delete fallback pattern
- Edit mode with validation
- Optimistic updates for favorites

### ❌ What We Need

**Models:**
- `SchoolStatusHistory` model
- `FitScoreResult` model
- `FitScoreBreakdown` model
- `FitTier` enum
- `DivisionRecommendation` model
- `CollegeDataResult` model
- `EditableBasicInfo` struct
- Extended `AcademicInfo` with missing fields
- `SchoolStatus` enum (from String)
- `PriorityTier` enum (from String)

**Services:**
- `SchoolsManaging` extensions:
  - `fetchSchool(id:)` - single school fetch
  - `updateSchool(id:updates:)` - partial updates
  - `updateStatus(id:newStatus:)` - status + history
  - `fetchStatusHistory(schoolId:)` - history entries
  - `updateBasicInfo(id:info:)` - academic info merge
  - `addPro(id:text:)` / `removePro(id:index:)`
  - `addCon(id:text:)` / `removeCon(id:index:)`
  - `updateNotes(id:notes:)` - shared notes
  - `updatePrivateNotes(id:userId:note:)` - private notes
  - `updateCoachingPhilosophy(id:philosophy:)` - 5 fields
- `FitScoreService` (new):
  - `calculateFitScore(schoolId:)` - client-side or API
  - `getDivisionRecommendations(division:fitScore:)` - logic
- `CollegeScorecardService` (new):
  - `lookupCollege(name:)` - external API

**ViewModels:**
- `SchoolDetailViewModel` - orchestrates all state

**Views:**
- `SchoolDetailView` - main scrollable view

**Components:**
- `SchoolDetailHeader` - name, badges, favorite star
- `SchoolQuickActions` - log interaction, send email, manage coaches
- `SchoolCoachesPanel` - up to 3 coaches with contact buttons
- `SchoolStatusHistorySection` - timeline of status changes
- `FitScoreSection` - score, tier, breakdown (collapsible)
- `DivisionRecommendationsCard` - conditional blue banner
- `SchoolInformationSection` - map, address, college data, edit mode
- `SchoolNotesSection` - shared notes with edit
- `PrivateNotesSection` - private notes with edit (user-keyed)
- `ProsConsSection` - two columns with add/remove
- `CoachingPhilosophySection` - 5 fields with edit mode
- `SchoolDocumentsSection` - read-only list (upload deferred)
- `SchoolAttributionSection` - created by, updated by
- `SchoolDeleteButton` - red delete with cascade

---

## Phase 1: Foundation & Basic Display (Day 1-1.5)

**Goal:** Display school header, status, basic info, and navigation.

### 1.1 Model Extensions

**File:** `TheRecruitingCompass/Features/Schools/Models/SchoolStatus.swift`
```swift
enum SchoolStatus: String, Codable, CaseIterable {
  case interested
  case contacted
  case campInvite = "camp_invite"
  case recruited
  case officialVisitInvited = "official_visit_invited"
  case officialVisitScheduled = "official_visit_scheduled"
  case offerReceived = "offer_received"
  case committed
  case notPursuing = "not_pursuing"

  var displayName: String { /* ... */ }
  var badgeColors: (background: Color, text: Color) { /* ... */ }
}
```

**File:** `TheRecruitingCompass/Features/Schools/Models/PriorityTier.swift`
```swift
enum PriorityTier: String, Codable, CaseIterable {
  case a = "A"
  case b = "B"
  case c = "C"

  var displayName: String { rawValue }
  var badgeColor: Color { /* Gold/Silver/Bronze */ }
}
```

**File:** `TheRecruitingCompass/Features/Schools/Models/SchoolStatusHistory.swift`
```swift
struct SchoolStatusHistory: Identifiable, Codable {
  let id: String
  let schoolId: String
  let previousStatus: String?
  let newStatus: String
  let changedBy: String
  let changedAt: Date
  let notes: String?
  let createdAt: Date

  enum CodingKeys: String, CodingKey { /* snake_case */ }
}
```

**File:** `TheRecruitingCompass/Features/Dashboard/Models/School.swift` (extend `AcademicInfo`)
```swift
struct AcademicInfo: Codable, Sendable {
  // Existing fields...
  let baseballFacilityAddress: String?
  let mascot: String?
  let undergradSize: String?
  let carnegieSize: String?
  let tuitionInState: Double?
  let tuitionOutOfState: Double?
  let admissionRate: Double?
  let distanceFromHome: Double?

  enum CodingKeys: String, CodingKey { /* snake_case */ }
}
```

**File:** `TheRecruitingCompass/Features/Dashboard/Models/School.swift` (add `privateNotes`)
```swift
struct School: Codable, Identifiable, Sendable {
  // ... existing fields
  let privateNotes: [String: String]?  // ADD THIS

  // Helper method
  func privateNote(for userId: String) -> String? {
    privateNotes?[userId]
  }
}
```

### 1.2 Service Extensions

**File:** `TheRecruitingCompass/Features/Schools/Services/SchoolsManaging.swift`
```swift
protocol SchoolsManaging: Sendable {
  // Existing methods...
  func fetchSchool(id: String, familyUnitId: String) async throws -> School
  func updateStatus(
    id: String,
    newStatus: SchoolStatus,
    previousStatus: SchoolStatus,
    userId: String
  ) async throws -> School
  func fetchStatusHistory(schoolId: String) async throws -> [SchoolStatusHistory]
}
```

**File:** `TheRecruitingCompass/Features/Schools/Services/SchoolsServiceImpl.swift` (implement new methods)
```swift
func fetchSchool(id: String, familyUnitId: String) async throws -> School {
  let response = try await supabaseManager.client
    .from("schools")
    .select("*")
    .eq("id", value: id)
    .eq("family_unit_id", value: familyUnitId)
    .single()
    .execute()

  return try JSONDecoder().decode(School.self, from: response.data)
}

func updateStatus(
  id: String,
  newStatus: SchoolStatus,
  previousStatus: SchoolStatus,
  userId: String
) async throws -> School {
  let now = Date()

  // 1. Update school status
  let schoolUpdate: [String: Any] = [
    "status": newStatus.rawValue,
    "status_changed_at": ISO8601DateFormatter().string(from: now),
    "updated_by": userId
  ]

  let updatedSchool = try await /* update query */

  // 2. Create history entry
  let historyEntry: [String: Any] = [
    "school_id": id,
    "previous_status": previousStatus.rawValue,
    "new_status": newStatus.rawValue,
    "changed_by": userId,
    "changed_at": ISO8601DateFormatter().string(from: now)
  ]

  try await /* insert history */

  return updatedSchool
}

func fetchStatusHistory(schoolId: String) async throws -> [SchoolStatusHistory] {
  let response = try await supabaseManager.client
    .from("school_status_history")
    .select("*")
    .eq("school_id", value: schoolId)
    .order("changed_at", ascending: false)
    .execute()

  return try JSONDecoder().decode([SchoolStatusHistory].self, from: response.data)
}
```

### 1.3 ViewModel

**File:** `TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift`
```swift
@MainActor
final class SchoolDetailViewModel: ObservableObject {
  @Published var school: School?
  @Published var isLoading = false
  @Published var errorMessage: String?

  // Status management
  @Published var statusHistory: [SchoolStatusHistory] = []
  @Published var isUpdatingStatus = false

  // Dependencies
  private let schoolId: String
  private let schoolsService: any SchoolsManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager

  nonisolated init(
    schoolId: String,
    schoolsService: any SchoolsManaging = SchoolsServiceImpl(supabaseManager: .shared),
    authManager: any AuthManaging = AuthManager.shared,
    familyManager: FamilyManager = .shared
  ) {
    self.schoolId = schoolId
    self.schoolsService = schoolsService
    self.authManager = authManager
    self.familyManager = familyManager
  }

  // MARK: - Loading

  func loadSchool() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    guard let familyId = familyManager.activeFamilyUnit?.id else {
      errorMessage = "No active family"
      return
    }

    do {
      async let schoolData = schoolsService.fetchSchool(id: schoolId, familyUnitId: familyId)
      async let historyData = schoolsService.fetchStatusHistory(schoolId: schoolId)

      school = try await schoolData
      statusHistory = try await historyData
    } catch {
      errorMessage = "Failed to load school: \(error.localizedDescription)"
    }
  }

  // MARK: - Status Update

  func updateStatus(to newStatus: SchoolStatus) async {
    guard let school, let userId = authManager.user?.id else { return }

    let previousStatus = SchoolStatus(rawValue: school.status) ?? .interested
    guard newStatus != previousStatus else { return }

    isUpdatingStatus = true
    defer { isUpdatingStatus = false }

    do {
      let updated = try await schoolsService.updateStatus(
        id: schoolId,
        newStatus: newStatus,
        previousStatus: previousStatus,
        userId: userId
      )
      self.school = updated

      // Refresh history
      statusHistory = try await schoolsService.fetchStatusHistory(schoolId: schoolId)
    } catch {
      errorMessage = "Failed to update status"
    }
  }
}
```

### 1.4 View Components

**File:** `TheRecruitingCompass/Features/Schools/Components/SchoolDetailHeader.swift`
```swift
struct SchoolDetailHeader: View {
  let school: School
  let onToggleFavorite: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        // School logo or initials
        SchoolLogoView(faviconUrl: school.faviconUrl, initials: school.initials)
          .frame(width: 56, height: 56)

        VStack(alignment: .leading, spacing: 4) {
          Text(school.name)
            .font(.title2)
            .fontWeight(.bold)

          if let location = school.location {
            Label(location, systemImage: "mappin.circle.fill")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        Button(action: onToggleFavorite) {
          Image(systemName: school.isFavorite ? "star.fill" : "star")
            .foregroundStyle(school.isFavorite ? .yellow : .gray)
            .font(.title2)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(school.isFavorite ? "Unfavorite" : "Favorite")
      }

      // Badges row
      HStack(spacing: 8) {
        if let division = school.division {
          DivisionBadge(division: division)
        }

        StatusBadge(status: SchoolStatus(rawValue: school.status) ?? .interested)

        if let tier = school.priorityTier {
          PriorityTierBadge(tier: PriorityTier(rawValue: tier))
        }

        if let size = school.size {
          SizeBadge(size: size)
        }

        if let conference = school.conference {
          ConferenceBadge(conference: conference)
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
  }
}
```

**File:** `TheRecruitingCompass/Features/Schools/Components/SchoolStatusHistorySection.swift`
```swift
struct SchoolStatusHistorySection: View {
  let history: [SchoolStatusHistory]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Status History")

      if history.isEmpty {
        Text("No status changes yet")
          .foregroundStyle(.secondary)
          .italic()
      } else {
        VStack(spacing: 8) {
          ForEach(history) { entry in
            StatusHistoryRow(entry: entry)
          }
        }
      }
    }
    .padding()
  }
}

struct StatusHistoryRow: View {
  let entry: SchoolStatusHistory

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          if let previous = entry.previousStatus {
            Text(previous)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Image(systemName: "arrow.right")
            .font(.caption)
            .foregroundStyle(.secondary)

          Text(entry.newStatus)
            .font(.caption)
            .fontWeight(.semibold)
        }

        Text(entry.changedAt, style: .relative)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }

      Spacer()
    }
  }
}
```

### 1.5 Main View

**File:** `TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift`
```swift
struct SchoolDetailView: View {
  let schoolId: String

  @StateObject private var viewModel: SchoolDetailViewModel
  @Environment(\.dismiss) private var dismiss

  init(schoolId: String) {
    self.schoolId = schoolId
    _viewModel = StateObject(wrappedValue: SchoolDetailViewModel(schoolId: schoolId))
  }

  var body: some View {
    ScrollView {
      if viewModel.isLoading {
        LoadingStateView(message: "Loading school...")
          .padding(.top, 100)
      } else if let school = viewModel.school {
        detailContent(school: school)
      } else if let error = viewModel.errorMessage {
        ErrorStateView(message: error)
          .padding(.top, 100)
      }
    }
    .navigationTitle("School Details")
    .navigationBarTitleDisplayMode(.inline)
    .refreshable {
      await viewModel.loadSchool()
    }
    .task {
      await viewModel.loadSchool()
    }
  }

  private func detailContent(school: School) -> some View {
    VStack(spacing: 24) {
      SchoolDetailHeader(
        school: school,
        onToggleFavorite: {
          // TODO: Phase 2
        }
      )

      // Status picker
      statusPickerSection(school: school)

      SchoolStatusHistorySection(history: viewModel.statusHistory)

      // TODO: Add more sections in subsequent phases
    }
  }

  private func statusPickerSection(school: School) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Recruiting Status")
        .font(.headline)

      Picker("Status", selection: Binding(
        get: { SchoolStatus(rawValue: school.status) ?? .interested },
        set: { newStatus in
          Task { await viewModel.updateStatus(to: newStatus) }
        }
      )) {
        ForEach(SchoolStatus.allCases, id: \.self) { status in
          Text(status.displayName).tag(status)
        }
      }
      .pickerStyle(.menu)
      .disabled(viewModel.isUpdatingStatus)
    }
    .padding()
  }
}
```

### 1.6 Update Navigation

**File:** `TheRecruitingCompass/Features/Schools/Views/SchoolsListView.swift` (update destination)
```swift
.navigationDestination(for: SchoolDestination.self) { destination in
  switch destination {
  case .detail(let schoolId):
    SchoolDetailView(schoolId: schoolId)  // REPLACE placeholder
  case .add:
    Text("Add School")
  }
}
```

### 1.7 Testing

**File:** `TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailViewModelTests.swift`
```swift
@MainActor
final class SchoolDetailViewModelTests: XCTestCase {
  func testLoadSchool() async throws {
    // Test successful load
  }

  func testUpdateStatus() async throws {
    // Test status update creates history entry
  }

  func testErrorHandling() async throws {
    // Test network errors
  }
}
```

**Deliverables:**
- ✅ School loads with header, badges, status
- ✅ Status picker updates and creates history
- ✅ Status history timeline displays
- ✅ Navigation from Schools List works
- ✅ 10+ ViewModel unit tests

---

## Phase 2: Editing & Notes (Day 1.5-2.5)

**Goal:** Add favorite toggle, notes editing (shared and private), pros/cons, basic info editing.

### 2.1 Model Extensions

**File:** `TheRecruitingCompass/Features/Schools/Models/EditableBasicInfo.swift`
```swift
struct EditableBasicInfo {
  var address: String = ""
  var baseballFacilityAddress: String = ""
  var mascot: String = ""
  var undergradSize: String = ""
  var website: String = ""
  var twitterHandle: String = ""
  var instagramHandle: String = ""

  static func from(school: School) -> EditableBasicInfo {
    EditableBasicInfo(
      address: school.academicInfo?.address ?? "",
      baseballFacilityAddress: school.academicInfo?.baseballFacilityAddress ?? "",
      mascot: school.academicInfo?.mascot ?? "",
      undergradSize: school.academicInfo?.undergradSize ?? "",
      website: school.website ?? "",
      twitterHandle: school.twitterHandle ?? "",
      instagramHandle: school.instagramHandle ?? ""
    )
  }
}
```

### 2.2 Service Extensions

**File:** `TheRecruitingCompass/Features/Schools/Services/SchoolsManaging.swift`
```swift
protocol SchoolsManaging: Sendable {
  // ... existing
  func updateNotes(id: String, notes: String) async throws -> School
  func updatePrivateNotes(id: String, userId: String, note: String?) async throws -> School
  func addPro(id: String, text: String) async throws -> School
  func removePro(id: String, index: Int) async throws -> School
  func addCon(id: String, text: String) async throws -> School
  func removeCon(id: String, index: Int) async throws -> School
  func updateBasicInfo(id: String, info: EditableBasicInfo) async throws -> School
}
```

### 2.3 ViewModel Extensions

**File:** `TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift` (extend)
```swift
// Add to SchoolDetailViewModel:

// MARK: - Favorite Toggle

@Published var isTogglingFavorite = false

func toggleFavorite() async {
  guard let school else { return }

  let newValue = !school.isFavorite

  // Optimistic update
  self.school = school.with(isFavorite: newValue)

  isTogglingFavorite = true
  defer { isTogglingFavorite = false }

  do {
    try await schoolsService.toggleFavorite(id: schoolId, isFavorite: newValue)
  } catch {
    // Revert on error
    self.school = school.with(isFavorite: !newValue)
    errorMessage = "Failed to update favorite"
  }
}

// MARK: - Notes

@Published var isEditingNotes = false
@Published var editedNotes = ""

func startEditingNotes() {
  editedNotes = school?.notes ?? ""
  isEditingNotes = true
}

func cancelEditingNotes() {
  editedNotes = ""
  isEditingNotes = false
}

func saveNotes() async {
  guard !editedNotes.isEmpty else { return }

  do {
    let updated = try await schoolsService.updateNotes(id: schoolId, notes: editedNotes)
    school = updated
    isEditingNotes = false
  } catch {
    errorMessage = "Failed to save notes"
  }
}

// MARK: - Private Notes

@Published var isEditingPrivateNotes = false
@Published var editedPrivateNotes = ""

var privateNoteForCurrentUser: String {
  guard let userId = authManager.user?.id else { return "" }
  return school?.privateNote(for: userId) ?? ""
}

func startEditingPrivateNotes() {
  editedPrivateNotes = privateNoteForCurrentUser
  isEditingPrivateNotes = true
}

func savePrivateNotes() async {
  guard let userId = authManager.user?.id else { return }

  do {
    let note = editedPrivateNotes.isEmpty ? nil : editedPrivateNotes
    let updated = try await schoolsService.updatePrivateNotes(
      id: schoolId,
      userId: userId,
      note: note
    )
    school = updated
    isEditingPrivateNotes = false
  } catch {
    errorMessage = "Failed to save private notes"
  }
}

// MARK: - Pros & Cons

@Published var newPro = ""
@Published var newCon = ""

func addPro() async {
  guard !newPro.isEmpty else { return }

  do {
    let updated = try await schoolsService.addPro(id: schoolId, text: newPro)
    school = updated
    newPro = ""
  } catch {
    errorMessage = "Failed to add pro"
  }
}

func removePro(at index: Int) async {
  do {
    let updated = try await schoolsService.removePro(id: schoolId, index: index)
    school = updated
  } catch {
    errorMessage = "Failed to remove pro"
  }
}

func addCon() async {
  guard !newCon.isEmpty else { return }

  do {
    let updated = try await schoolsService.addCon(id: schoolId, text: newCon)
    school = updated
    newCon = ""
  } catch {
    errorMessage = "Failed to add con"
  }
}

func removeCon(at index: Int) async {
  do {
    let updated = try await schoolsService.removeCon(id: schoolId, index: index)
    school = updated
  } catch {
    errorMessage = "Failed to remove con"
  }
}

// MARK: - Basic Info

@Published var isEditingBasicInfo = false
@Published var editedBasicInfo = EditableBasicInfo()

func startEditingBasicInfo() {
  guard let school else { return }
  editedBasicInfo = EditableBasicInfo.from(school: school)
  isEditingBasicInfo = true
}

func saveBasicInfo() async {
  do {
    let updated = try await schoolsService.updateBasicInfo(
      id: schoolId,
      info: editedBasicInfo
    )
    school = updated
    isEditingBasicInfo = false
  } catch {
    errorMessage = "Failed to save information"
  }
}
```

### 2.4 View Components

**File:** `TheRecruitingCompass/Features/Schools/Components/SchoolNotesSection.swift`
```swift
struct SchoolNotesSection: View {
  let notes: String
  let isEditing: Bool
  @Binding var editedNotes: String
  let onEdit: () -> Void
  let onSave: () async -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SectionHeader(title: "Notes")
        Spacer()
        if !isEditing {
          Button("Edit", action: onEdit)
        }
      }

      if isEditing {
        TextEditor(text: $editedNotes)
          .frame(minHeight: 120)
          .padding(8)
          .background(Color(.systemGray6))
          .cornerRadius(8)

        HStack {
          Button("Cancel", action: onCancel)
          Spacer()
          Button("Save") {
            Task { await onSave() }
          }
          .buttonStyle(.borderedProminent)
        }
      } else {
        Text(notes.isEmpty ? "No notes added yet." : notes)
          .foregroundStyle(notes.isEmpty ? .secondary : .primary)
          .italic(notes.isEmpty)
      }
    }
    .padding()
  }
}
```

**File:** `TheRecruitingCompass/Features/Schools/Components/SchoolProsConsSection.swift`
```swift
struct SchoolProsConsSection: View {
  let pros: [String]
  let cons: [String]
  @Binding var newPro: String
  @Binding var newCon: String
  let onAddPro: () async -> Void
  let onRemovePro: (Int) async -> Void
  let onAddCon: () async -> Void
  let onRemoveCon: (Int) async -> Void

  var body: some View {
    VStack(spacing: 16) {
      SectionHeader(title: "Pros & Cons")

      HStack(alignment: .top, spacing: 16) {
        // Pros column
        VStack(alignment: .leading, spacing: 8) {
          Text("Pros")
            .font(.subheadline)
            .fontWeight(.semibold)

          ForEach(Array(pros.enumerated()), id: \.offset) { index, pro in
            ProsItem(text: pro) {
              Task { await onRemovePro(index) }
            }
          }

          HStack {
            TextField("Add a pro...", text: $newPro)
              .textFieldStyle(.roundedBorder)

            Button(action: { Task { await onAddPro() } }) {
              Image(systemName: "plus.circle.fill")
                .foregroundStyle(.green)
            }
            .disabled(newPro.isEmpty)
          }
        }

        // Cons column
        VStack(alignment: .leading, spacing: 8) {
          Text("Cons")
            .font(.subheadline)
            .fontWeight(.semibold)

          ForEach(Array(cons.enumerated()), id: \.offset) { index, con in
            ConsItem(text: con) {
              Task { await onRemoveCon(index) }
            }
          }

          HStack {
            TextField("Add a con...", text: $newCon)
              .textFieldStyle(.roundedBorder)

            Button(action: { Task { await onAddCon() } }) {
              Image(systemName: "plus.circle.fill")
                .foregroundStyle(.red)
            }
            .disabled(newCon.isEmpty)
          }
        }
      }
    }
    .padding()
  }
}
```

### 2.5 Update Main View

Add sections to `SchoolDetailView`:
- Notes section
- Private notes section
- Pros & Cons section
- Basic info edit modal

**Deliverables:**
- ✅ Favorite toggle with optimistic update
- ✅ Shared notes edit and save
- ✅ Private notes edit and save (user-keyed)
- ✅ Pros/cons add and remove
- ✅ Basic info edit modal
- ✅ 15+ ViewModel tests for editing

---

## Phase 3: Fit Score & External APIs (Day 2.5-3.5)

**Goal:** Add fit score display, College Scorecard lookup, map view, distance calculation.

### 3.1 Models

**File:** `TheRecruitingCompass/Features/Schools/Models/FitScore.swift`
```swift
struct FitScoreResult: Codable {
  let score: Double
  let tier: FitTier
  let breakdown: FitScoreBreakdown
  let missingDimensions: [String]
}

struct FitScoreBreakdown: Codable {
  let athleticFit: Double?
  let academicFit: Double?
  let opportunityFit: Double?
  let personalFit: Double?
}

enum FitTier: String, Codable {
  case reach
  case match
  case safety
  case unlikely

  var displayName: String { /* ... */ }
  var badgeColors: (background: Color, text: Color) { /* ... */ }
}

struct DivisionRecommendation {
  let shouldConsiderOtherDivisions: Bool
  let recommendedDivisions: [String]
  let message: String
}
```

**File:** `TheRecruitingCompass/Features/Schools/Models/CollegeDataResult.swift`
```swift
struct CollegeDataResult: Codable {
  let id: String
  let name: String
  let website: String?
  let address: String?
  let city: String?
  let state: String?
  let studentSize: Int?
  let carnegieSize: String?
  let admissionRate: Double?
  let tuitionInState: Double?
  let tuitionOutOfState: Double?
  let latitude: Double?
  let longitude: Double?
}

enum CollegeDataError: LocalizedError {
  case nameTooShort
  case apiKeyMissing
  case invalidApiKey
  case rateLimited
  case schoolNotFound
  case invalidResponse
  case serverError(Int)

  var errorDescription: String? { /* ... */ }
}
```

### 3.2 Services

**File:** `TheRecruitingCompass/Features/Schools/Services/FitScoreService.swift`
```swift
protocol FitScoreManaging: Sendable {
  func calculateFitScore(schoolId: String) async throws -> FitScoreResult
  func getDivisionRecommendations(
    division: String?,
    fitScore: Double?
  ) -> DivisionRecommendation
}

final class FitScoreService: FitScoreManaging {
  // Implementation based on web's useFitScore composable
  // Could be client-side calculation or API call
}
```

**File:** `TheRecruitingCompass/Features/Schools/Services/CollegeScorecardService.swift`
```swift
protocol CollegeScorecardManaging: Sendable {
  func lookupCollege(name: String) async throws -> CollegeDataResult?
}

final class CollegeScorecardService: CollegeScorecardManaging {
  private let apiKey: String

  func lookupCollege(name: String) async throws -> CollegeDataResult? {
    guard name.count >= 3 else {
      throw CollegeDataError.nameTooShort
    }

    // Build URL with query parameters
    var components = URLComponents(
      string: "https://api.data.gov/ed/collegescorecard/v1/schools"
    )!

    components.queryItems = [
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "school.name", value: name),
      URLQueryItem(name: "fields", value: /* field list */),
      URLQueryItem(name: "per_page", value: "1")
    ]

    // Fetch and decode
    // See Appendix E in spec for full implementation
  }
}
```

### 3.3 ViewModel Extensions

```swift
// Add to SchoolDetailViewModel:

@Published var fitScore: FitScoreResult?
@Published var divisionRecommendation: DivisionRecommendation?
@Published var isLoadingFitScore = false

@Published var isLookingUpCollegeData = false
@Published var collegeDataError: String?

private let fitScoreService: any FitScoreManaging
private let collegeService: any CollegeScorecardManaging

func loadFitScore() async {
  isLoadingFitScore = true
  defer { isLoadingFitScore = false }

  do {
    fitScore = try await fitScoreService.calculateFitScore(schoolId: schoolId)

    if let score = fitScore?.score {
      divisionRecommendation = fitScoreService.getDivisionRecommendations(
        division: school?.division,
        fitScore: score
      )
    }
  } catch {
    // Non-critical, just hide section
  }
}

func lookupCollegeData() async {
  guard let schoolName = school?.name else { return }

  isLookingUpCollegeData = true
  collegeDataError = nil
  defer { isLookingUpCollegeData = false }

  do {
    guard let data = try await collegeService.lookupCollege(name: schoolName) else {
      collegeDataError = "School not found in database"
      return
    }

    // Merge data into school's academic_info
    let updatedInfo = mergeCollegeData(data, into: school?.academicInfo)
    try await schoolsService.updateAcademicInfo(id: schoolId, info: updatedInfo)

    // Reload school
    await loadSchool()
  } catch let error as CollegeDataError {
    collegeDataError = error.errorDescription
  } catch {
    collegeDataError = "Failed to lookup college data"
  }
}
```

### 3.4 View Components

**File:** `TheRecruitingCompass/Features/Schools/Components/FitScoreSection.swift`
```swift
struct FitScoreSection: View {
  let fitScore: FitScoreResult
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "School Fit Analysis")

      HStack {
        Text("\(Int(fitScore.score))")
          .font(.largeTitle)
          .fontWeight(.bold)
          .foregroundStyle(fitScoreColor(fitScore.score))

        FitTierBadge(tier: fitScore.tier)

        Spacer()

        Button(action: { isExpanded.toggle() }) {
          Label(
            isExpanded ? "Hide Breakdown" : "Show Breakdown",
            systemImage: isExpanded ? "chevron.up" : "chevron.down"
          )
        }
      }

      if isExpanded {
        VStack(alignment: .leading, spacing: 8) {
          if let athletic = fitScore.breakdown.athleticFit {
            BreakdownRow(label: "Athletic Fit", score: athletic)
          }
          if let academic = fitScore.breakdown.academicFit {
            BreakdownRow(label: "Academic Fit", score: academic)
          }
          if let opportunity = fitScore.breakdown.opportunityFit {
            BreakdownRow(label: "Opportunity Fit", score: opportunity)
          }
          if let personal = fitScore.breakdown.personalFit {
            BreakdownRow(label: "Personal Fit", score: personal)
          }
        }

        if !fitScore.missingDimensions.isEmpty {
          Text("Missing data: \(fitScore.missingDimensions.joined(separator: ", "))")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      }
    }
    .padding()
  }
}
```

**File:** `TheRecruitingCompass/Features/Schools/Components/SchoolInformationSection.swift`
```swift
import MapKit

struct SchoolInformationSection: View {
  let school: School
  let homeLocation: CLLocationCoordinate2D?
  let isEditing: Bool
  @Binding var editedInfo: EditableBasicInfo
  let onEdit: () -> Void
  let onSave: () async -> Void
  let onLookup: () async -> Void
  let isLookingUp: Bool
  let lookupError: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SectionHeader(title: "Information")
        Spacer()

        if !isEditing {
          Button("Lookup") {
            Task { await onLookup() }
          }
          .disabled(isLookingUp)

          Button("Edit", action: onEdit)
        }
      }

      // Map view (if coordinates available)
      if let lat = school.academicInfo?.latitude,
         let lon = school.academicInfo?.longitude {
        Map(coordinateRegion: .constant(
          MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
          )
        ), annotationItems: [MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))]) { item in
          MapMarker(coordinate: item.coordinate, tint: .blue)
        }
        .frame(height: 180)
        .cornerRadius(12)
      }

      // Distance from home
      if let distance = calculateDistance() {
        Text("Distance from Home: \(Int(distance)) miles")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      // Editable/display fields
      if isEditing {
        // Edit mode form fields
      } else {
        // Display mode
      }

      // College Scorecard data
      if let info = school.academicInfo {
        VStack(alignment: .leading, spacing: 8) {
          Text("College Scorecard Data")
            .font(.headline)
            .padding(.top, 8)

          if let size = info.studentSize {
            InfoRow(label: "Students", value: "\(size)")
          }
          // ... other fields
        }
      }
    }
    .padding()
  }

  private func calculateDistance() -> Double? {
    guard let homeLoc = homeLocation,
          let lat = school.academicInfo?.latitude,
          let lon = school.academicInfo?.longitude else { return nil }

    let home = CLLocation(latitude: homeLoc.latitude, longitude: homeLoc.longitude)
    let schoolLoc = CLLocation(latitude: lat, longitude: lon)
    return home.distance(from: schoolLoc) / 1609.34 // meters to miles
  }
}
```

**Deliverables:**
- ✅ Fit score displays with breakdown
- ✅ Division recommendations (conditional)
- ✅ Map view with school pin
- ✅ Distance from home calculation
- ✅ College Scorecard lookup and merge
- ✅ 10+ tests for fit score and lookup

---

## Phase 4: Coaches, Actions & Final Features (Day 3.5-4.5)

**Goal:** Add coaches panel with contact actions, coaching philosophy editing, documents, delete.

### 4.1 ViewModel Extensions

```swift
// Add to SchoolDetailViewModel:

@Published var coaches: [Coach] = []
@Published var isEditingCoachingPhilosophy = false
@Published var editedPhilosophy = CoachingPhilosophy()

private let coachesService: any CoachesManaging

func loadCoaches() async {
  do {
    coaches = try await coachesService.fetchCoaches(schoolId: schoolId)
  } catch {
    // Non-critical
  }
}

// MARK: - Coaching Philosophy

struct CoachingPhilosophy {
  var coachingStyle: String = ""
  var recruitingApproach: String = ""
  var communicationStyle: String = ""
  var successMetrics: String = ""
  var overallPhilosophy: String = ""

  static func from(school: School) -> CoachingPhilosophy {
    CoachingPhilosophy(
      coachingStyle: school.coachingStyle ?? "",
      recruitingApproach: school.recruitingApproach ?? "",
      communicationStyle: school.communicationStyle ?? "",
      successMetrics: school.successMetrics ?? "",
      overallPhilosophy: school.coachingPhilosophy ?? ""
    )
  }
}

func startEditingCoachingPhilosophy() {
  guard let school else { return }
  editedPhilosophy = CoachingPhilosophy.from(school: school)
  isEditingCoachingPhilosophy = true
}

func saveCoachingPhilosophy() async {
  do {
    try await schoolsService.updateCoachingPhilosophy(
      id: schoolId,
      philosophy: editedPhilosophy
    )
    await loadSchool()
    isEditingCoachingPhilosophy = false
  } catch {
    errorMessage = "Failed to save coaching philosophy"
  }
}

// MARK: - Delete

@Published var showDeleteConfirmation = false
@Published var isDeleting = false

func confirmDelete() {
  showDeleteConfirmation = true
}

func deleteSchool() async {
  isDeleting = true
  defer { isDeleting = false }

  do {
    // Try simple delete
    try await schoolsService.deleteSchool(id: schoolId)
    // Navigate back on success
  } catch {
    // Try cascade delete
    if error.localizedDescription.contains("foreign key") {
      do {
        let result = try await schoolsService.cascadeDeleteSchool(id: schoolId)
        // Show success message with counts
      } catch {
        errorMessage = error.localizedDescription
      }
    } else {
      errorMessage = error.localizedDescription
    }
  }
}
```

### 4.2 View Components

**File:** `TheRecruitingCompass/Features/Schools/Components/SchoolQuickActions.swift`
```swift
struct SchoolQuickActions: View {
  let schoolId: String

  var body: some View {
    VStack(spacing: 12) {
      NavigationLink(value: InteractionDestination.add(schoolId: schoolId)) {
        QuickActionButton(
          title: "Log Interaction",
          icon: "bubble.left.and.bubble.right",
          gradient: AppGradients.blue
        )
      }

      Button(action: { /* Present email modal */ }) {
        QuickActionButton(
          title: "Send Email",
          icon: "envelope",
          gradient: AppGradients.purple
        )
      }

      NavigationLink(value: CoachDestination.list(schoolId: schoolId)) {
        QuickActionButton(
          title: "Manage Coaches",
          icon: "person.2",
          gradient: AppGradients.slate
        )
      }
    }
    .padding()
  }
}
```

**File:** `TheRecruitingCompass/Features/Schools/Components/SchoolCoachesPanel.swift`
```swift
struct SchoolCoachesPanel: View {
  let coaches: [Coach]
  let onEmail: (Coach) -> Void
  let onSMS: (Coach) -> Void
  let onCall: (Coach) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SectionHeader(title: "Coaches")
        Spacer()
        NavigationLink("Manage", value: /* destination */)
      }

      if coaches.isEmpty {
        Text("No coaches added yet")
          .foregroundStyle(.secondary)
          .italic()
      } else {
        VStack(spacing: 8) {
          ForEach(coaches.prefix(3)) { coach in
            CoachContactCard(
              coach: coach,
              onEmail: { onEmail(coach) },
              onSMS: { onSMS(coach) },
              onCall: { onCall(coach) }
            )
          }
        }
      }
    }
    .padding()
  }
}

struct CoachContactCard: View {
  let coach: Coach
  let onEmail: () -> Void
  let onSMS: () -> Void
  let onCall: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(coach.fullName)
          .font(.headline)
        Text(coach.role.displayName)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 12) {
        if coach.email != nil {
          Button(action: onEmail) {
            Image(systemName: "envelope.fill")
              .foregroundStyle(.blue)
          }
          .frame(width: 34, height: 34)
          .accessibilityLabel("Email \(coach.fullName)")
        }

        if coach.phone != nil {
          Button(action: onSMS) {
            Image(systemName: "message.fill")
              .foregroundStyle(.green)
          }
          .frame(width: 34, height: 34)
          .accessibilityLabel("Text \(coach.fullName)")

          Button(action: onCall) {
            Image(systemName: "phone.fill")
              .foregroundStyle(.purple)
          }
          .frame(width: 34, height: 34)
          .accessibilityLabel("Call \(coach.fullName)")
        }
      }
    }
    .padding(12)
    .background(Color(.systemGray6))
    .cornerRadius(8)
  }
}
```

**File:** `TheRecruitingCompass/Features/Schools/Components/CoachingPhilosophySection.swift`
```swift
struct CoachingPhilosophySection: View {
  let philosophy: CoachingPhilosophy
  let isEditing: Bool
  @Binding var editedPhilosophy: CoachingPhilosophy
  let onEdit: () -> Void
  let onSave: () async -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SectionHeader(title: "Coaching Philosophy")
        Spacer()
        if !isEditing {
          Button("Edit", action: onEdit)
        }
      }

      if isEditing {
        VStack(spacing: 16) {
          PhilosophyField(
            label: "Coaching Style",
            text: $editedPhilosophy.coachingStyle
          )
          PhilosophyField(
            label: "Recruiting Approach",
            text: $editedPhilosophy.recruitingApproach
          )
          PhilosophyField(
            label: "Communication Style",
            text: $editedPhilosophy.communicationStyle
          )
          PhilosophyField(
            label: "Success Metrics",
            text: $editedPhilosophy.successMetrics
          )
          PhilosophyField(
            label: "Overall Philosophy",
            text: $editedPhilosophy.overallPhilosophy
          )

          HStack {
            Button("Cancel", action: onCancel)
            Spacer()
            Button("Save") {
              Task { await onSave() }
            }
            .buttonStyle(.borderedProminent)
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 12) {
          PhilosophyDisplay(label: "Coaching Style", text: philosophy.coachingStyle)
          PhilosophyDisplay(label: "Recruiting Approach", text: philosophy.recruitingApproach)
          PhilosophyDisplay(label: "Communication Style", text: philosophy.communicationStyle)
          PhilosophyDisplay(label: "Success Metrics", text: philosophy.successMetrics)
          PhilosophyDisplay(label: "Overall Philosophy", text: philosophy.overallPhilosophy)
        }
      }
    }
    .padding()
  }
}
```

### 4.3 Contact Actions

**File:** `TheRecruitingCompass/Features/Schools/Utilities/ContactActions.swift`
```swift
import UIKit
import MessageUI

struct ContactActions {
  static func email(to address: String) {
    if let url = URL(string: "mailto:\(address)"),
       UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url)
    }
  }

  static func sms(to phoneNumber: String) {
    let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    if let url = URL(string: "sms:\(cleanNumber)"),
       UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url)
    }
  }

  static func call(phoneNumber: String) {
    let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    if let url = URL(string: "tel:\(cleanNumber)"),
       UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url)
    }
  }
}
```

### 4.4 Final View Assembly

Update `SchoolDetailView` to include:
- Quick actions
- Coaches panel with contact buttons
- Coaching philosophy section
- Documents section (read-only)
- Attribution section
- Delete button

**Deliverables:**
- ✅ Quick action buttons (log interaction, email, manage coaches)
- ✅ Coaches panel shows up to 3 coaches
- ✅ Email/SMS/Call buttons work with native handlers
- ✅ Coaching philosophy 5-field edit
- ✅ Documents section (read-only list)
- ✅ Delete with cascade fallback
- ✅ Attribution footer
- ✅ 15+ tests for final features

---

## Testing Strategy

### Unit Tests (60+ total)

**SchoolDetailViewModelTests:**
- Load school success/failure
- Update status creates history
- Toggle favorite optimistic update
- Notes editing (shared and private)
- Pros/cons add/remove
- Basic info editing
- Fit score loading
- College data lookup
- Coaching philosophy editing
- Delete with cascade fallback

**Component Tests:**
- SchoolDetailHeader renders correctly
- Status history timeline displays
- Fit score breakdown expansion
- Map view conditional rendering
- Contact buttons accessibility

### Accessibility Tests (15+)

**SchoolDetailAccessibilityTests:**
- VoiceOver labels for all sections
- Status picker announces changes
- Favorite button announces state
- Contact buttons announce coach name
- Edit buttons announce purpose
- Dynamic Type support
- Touch targets 44pt minimum

### Integration Tests (5+)

- Full page load flow
- Status update with history creation
- College data lookup and merge
- Delete with cascade
- Navigation to sub-pages

---

## Dependencies & External Services

### Required Frameworks
- SwiftUI (iOS 16+)
- MapKit
- CoreLocation
- MessageUI (optional, for native email compose)

### External APIs
- College Scorecard API (data.gov)
  - API key from app config
  - Rate limited
  - Cache results in memory

### Supabase Tables
- `schools` (main data)
- `school_status_history` (status changes)
- `coaches` (for panel)
- `documents` (read-only list)

---

## Performance Considerations

### Optimizations
- Lazy load fit score (non-critical)
- Cache College Scorecard results in UserDefaults
- Debounce pro/con add inputs
- Optimistic updates for favorites
- Load coaches in parallel with school data

### Loading States
- Skeleton loaders for sections
- Progressive enhancement (show what's ready)
- Pull-to-refresh re-fetches all data

---

## Known Limitations & Deferred Features

### Deferred to Later Phases
- Document upload (show read-only list for MVP)
- Notes history (show current notes only)
- Recruiting packet generation
- Email compose modal (use native mailto:)
- Priority tier selector (show display only)

### Simplified for MVP
- Coaching philosophy: could start with single field, expand to 5 later
- Fit score: may be client-side only, no API recalculate
- Division recommendations: simple logic, may enhance later

---

## Migration from Web

### Key Differences
- **Layout:** Web uses 3-column layout; iOS flattens to scrollable sections
- **Status picker:** Web uses `<select>`; iOS uses native `Picker` or `Menu`
- **Map:** Web uses Leaflet; iOS uses MapKit
- **Contact actions:** Web uses modals; iOS uses native URL schemes
- **Document upload:** Web has modal; iOS defers to later phase

### Reusable Patterns
- Private notes dictionary structure
- Fit score calculation logic
- Division recommendation logic
- Status history creation
- Cascade delete fallback

---

## Acceptance Criteria

### Phase 1 Complete ✅
- [ ] School loads with header, badges, status
- [ ] Status picker updates and creates history
- [ ] Status history timeline displays
- [ ] Navigation from Schools List works
- [ ] 10+ ViewModel unit tests passing

### Phase 2 Complete ✅
- [ ] Favorite toggle with optimistic update
- [ ] Shared notes edit and save
- [ ] Private notes edit and save (user-keyed)
- [ ] Pros/cons add and remove
- [ ] Basic info edit modal
- [ ] 15+ ViewModel tests for editing

### Phase 3 Complete ✅
- [ ] Fit score displays with breakdown
- [ ] Division recommendations (conditional)
- [ ] Map view with school pin
- [ ] Distance from home calculation
- [ ] College Scorecard lookup and merge
- [ ] 10+ tests for fit score and lookup

### Phase 4 Complete ✅
- [ ] Quick action buttons working
- [ ] Coaches panel shows coaches
- [ ] Email/SMS/Call buttons work
- [ ] Coaching philosophy 5-field edit
- [ ] Documents section (read-only)
- [ ] Delete with cascade fallback
- [ ] 15+ tests for final features

### Overall Complete ✅
- [ ] All 60+ unit tests passing
- [ ] 15+ accessibility tests passing
- [ ] Build clean (0 errors, 0 warnings)
- [ ] Pull-to-refresh works
- [ ] VoiceOver navigation smooth
- [ ] Dynamic Type supported
- [ ] All error states handled
- [ ] Code review approved

---

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1 | 1-1.5 days | Basic display + status management |
| Phase 2 | 1 day | Editing + notes + pros/cons |
| Phase 3 | 1 day | Fit score + College API + map |
| Phase 4 | 1-1.5 days | Coaches + actions + delete |
| Testing & Polish | 0.5 days | Accessibility, edge cases |

**Total:** 4-5 days

---

## Risk Mitigation

### High-Risk Areas
1. **College Scorecard API:** May be slow or unavailable
   - Mitigation: Timeout, error handling, manual entry fallback
2. **Fit score calculation:** Complex logic from web
   - Mitigation: Start simple, iterate based on feedback
3. **Cascade delete:** FK constraints may be complex
   - Mitigation: Test thoroughly, provide clear error messages

### Contingency Plans
- If College API unreliable: Add manual entry fields
- If fit score too complex: Show basic score only, defer breakdown
- If coaching philosophy 5 fields too much: Start with single field

---

## Next Steps After Completion

1. **Code Review:** Use `code-reviewer` agent
2. **Accessibility Audit:** Use `a11y-wcag-auditor` agent
3. **Commit:** Create feature branch, commit with detailed message
4. **PR:** Create PR with full commit history analysis
5. **Integration:** Merge to main after approval
6. **Iteration:** Gather feedback, add deferred features

---

## Questions for Chris

1. **College Scorecard API Key:** Where should we store this? (Environment variable? App config?)
2. **Fit Score:** Client-side calculation or API endpoint? (Spec shows both)
3. **Coaching Philosophy:** Start with 5 fields or single field for MVP?
4. **Document Upload:** Completely defer or show placeholder button?
5. **Priority Tier Selector:** Editable in this phase or display-only?
6. **Email Modal:** Use native mailto: or build custom modal?

---

**End of Implementation Plan**
