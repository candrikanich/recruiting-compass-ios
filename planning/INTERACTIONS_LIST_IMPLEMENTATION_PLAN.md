# Interactions List - iOS Implementation Plan

**Created:** February 9, 2026
**Feature:** Interactions List (MVP Phase 2)
**Estimated Time:** 3 days
**Complexity:** Medium
**Spec:** `iOS_SPEC_Phase2_InteractionsList.md`

---

## 1. Overview

Implement a comprehensive interactions list view that displays all coaching communications logged by the athlete or their parents. The feature includes analytics cards, role-based access control (athletes vs parents), filtering/sorting, and follows established patterns from Coaches/Schools lists.

### Key Deliverables

1. ✅ Interaction model with all enums (Type, Direction, Sentiment, TimePeriod)
2. ✅ InteractionsManaging protocol + service implementation + mock
3. ✅ InteractionsListViewModel with filtering, sorting, analytics
4. ✅ Analytics cards component (4-card dashboard)
5. ✅ InteractionCard component
6. ✅ InteractionFilterBar component (reusable filter system)
7. ✅ InteractionsListView with search, pull-to-refresh, delete
8. ✅ Role-based access control (athlete vs parent)
9. ✅ Comprehensive unit tests (80%+ coverage)
10. ✅ Accessibility compliance (VoiceOver, Dynamic Type)

---

## 2. Architecture & Patterns

### Following Established Patterns

**Reference implementations:**
- Coaches List: `/Features/Coaches/`
- Schools List: `/Features/Schools/`
- Pattern: MVVM with protocol-based DI, client-side filtering, role-based access

### File Structure

```
Features/
└── Interactions/
    ├── Models/
    │   ├── Interaction.swift               # Main model with enums
    │   ├── InteractionFilters.swift        # Filter state
    │   └── InteractionAnalytics.swift      # Analytics model
    ├── Services/
    │   ├── InteractionsManaging.swift      # Protocol
    │   └── InteractionsServiceImpl.swift   # Supabase implementation
    ├── ViewModels/
    │   └── InteractionsListViewModel.swift # Business logic
    ├── Views/
    │   └── InteractionsListView.swift      # Main list view
    └── Components/
        ├── InteractionCard.swift           # Individual card
        ├── InteractionAnalyticsCards.swift # 4-card dashboard
        ├── InteractionFilterBar.swift      # Filter controls
        ├── InteractionEmptyState.swift     # Empty/no results states
        └── InteractionPrivacyNotice.swift  # Athletes only

Tests/
└── Features/
    └── Interactions/
        ├── ViewModels/
        │   └── InteractionsListViewModelTests.swift  # ~50 tests
        ├── Components/
        │   ├── InteractionCardTests.swift
        │   └── InteractionAnalyticsCardsTests.swift
        └── Accessibility/
            └── InteractionsAccessibilityTests.swift   # ~20 tests

Mocks/
└── MockInteractionsService.swift           # Test doubles
```

---

## 3. Phase-by-Phase Implementation

### Phase 1: Models & Enums (30 minutes)

**Goal:** Define all data structures matching Supabase schema

**Files to create:**
1. `Interaction.swift` (main model)
2. `InteractionFilters.swift` (filter state)
3. `InteractionAnalytics.swift` (analytics model)

**Implementation:**

```swift
// Features/Interactions/Models/Interaction.swift
import Foundation

struct Interaction: Identifiable, Codable, Sendable {
  let id: String
  let type: InteractionType
  let direction: Direction
  let schoolId: String?
  let coachId: String?
  let subject: String?
  let content: String?
  let sentiment: Sentiment?
  let occurredAt: String?         // ISO8601 string
  let loggedBy: String?           // User ID
  let attachments: [String]?
  let familyUnitId: String
  let createdAt: String
  let updatedAt: String

  // Computed properties
  var displayDate: Date {
    if let occurredAt, let date = iso8601Formatter.date(from: occurredAt) {
      return date
    }
    if let createdAt, let date = iso8601Formatter.date(from: createdAt) {
      return date
    }
    return Date()
  }

  var hasAttachments: Bool {
    !(attachments ?? []).isEmpty
  }

  var attachmentCount: Int {
    (attachments ?? []).count
  }

  private static let iso8601Formatter = ISO8601DateFormatter()

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case direction
    case schoolId = "school_id"
    case coachId = "coach_id"
    case subject
    case content
    case sentiment
    case occurredAt = "occurred_at"
    case loggedBy = "logged_by"
    case attachments
    case familyUnitId = "family_unit_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

enum InteractionType: String, Codable, CaseIterable {
  case email
  case phoneCall = "phone_call"
  case text
  case inPersonVisit = "in_person_visit"
  case virtualMeeting = "virtual_meeting"
  case camp
  case showcase
  case tweet
  case directMessage = "dm"

  var displayName: String {
    switch self {
    case .email: return "Email"
    case .phoneCall: return "Phone Call"
    case .text: return "Text"
    case .inPersonVisit: return "In-Person Visit"
    case .virtualMeeting: return "Virtual Meeting"
    case .camp: return "Camp"
    case .showcase: return "Showcase"
    case .tweet: return "Tweet"
    case .directMessage: return "Direct Message"
    }
  }

  var iconName: String {
    switch self {
    case .email: return "envelope.fill"
    case .phoneCall: return "phone.fill"
    case .text: return "bubble.left.fill"
    case .inPersonVisit: return "person.2.fill"
    case .virtualMeeting: return "video.fill"
    case .camp: return "figure.run"
    case .showcase: return "star.fill"
    case .tweet: return "bubble.left.fill"
    case .directMessage: return "paperplane.fill"
    }
  }

  var iconColor: Color {
    switch self {
    case .email: return .blue
    case .phoneCall: return .purple
    case .text: return .green
    case .inPersonVisit: return .orange
    case .virtualMeeting: return .indigo
    case .camp: return .orange
    case .showcase: return .pink
    case .tweet: return .cyan
    case .directMessage: return .purple
    }
  }
}

enum Direction: String, Codable, CaseIterable {
  case outbound
  case inbound

  var displayName: String {
    switch self {
    case .outbound: return "Outbound"
    case .inbound: return "Inbound"
    }
  }

  var badgeColor: Color {
    switch self {
    case .outbound: return .blue
    case .inbound: return .green
    }
  }
}

enum Sentiment: String, Codable, CaseIterable {
  case veryPositive = "very_positive"
  case positive
  case neutral
  case negative

  var displayName: String {
    switch self {
    case .veryPositive: return "Very Positive"
    case .positive: return "Positive"
    case .neutral: return "Neutral"
    case .negative: return "Negative"
    }
  }

  var badgeColor: Color {
    switch self {
    case .veryPositive: return .green
    case .positive: return .blue
    case .neutral: return .gray
    case .negative: return .red
    }
  }
}

enum TimePeriod: Int, CaseIterable {
  case last7Days = 7
  case last14Days = 14
  case last30Days = 30
  case last90Days = 90

  var displayName: String {
    switch self {
    case .last7Days: return "Last 7 days"
    case .last14Days: return "Last 14 days"
    case .last30Days: return "Last 30 days"
    case .last90Days: return "Last 90 days"
    }
  }
}

// Features/Interactions/Models/InteractionFilters.swift
struct InteractionFilters {
  var searchText: String = ""
  var type: InteractionType? = nil
  var direction: Direction? = nil
  var sentiment: Sentiment? = nil
  var timePeriod: TimePeriod? = nil
  var loggedBy: String? = nil       // User ID (parents only)

  var hasActiveFilters: Bool {
    !searchText.isEmpty || type != nil || direction != nil ||
    sentiment != nil || timePeriod != nil || loggedBy != nil
  }

  var activeFilterCount: Int {
    var count = 0
    if !searchText.isEmpty { count += 1 }
    if type != nil { count += 1 }
    if direction != nil { count += 1 }
    if sentiment != nil { count += 1 }
    if timePeriod != nil { count += 1 }
    if loggedBy != nil { count += 1 }
    return count
  }
}

// Features/Interactions/Models/InteractionAnalytics.swift
struct InteractionAnalytics {
  let totalCount: Int
  let outboundCount: Int
  let inboundCount: Int
  let thisWeekCount: Int
}
```

**Verification:**
- Run build: All models compile
- No errors/warnings

---

### Phase 2: Service Layer (45 minutes)

**Goal:** Protocol + implementation + mock for data fetching

**Files to create:**
1. `InteractionsManaging.swift` (protocol)
2. `InteractionsServiceImpl.swift` (Supabase implementation)
3. `MockInteractionsService.swift` (test double)

**Implementation:**

```swift
// Features/Interactions/Services/InteractionsManaging.swift
import Foundation

protocol InteractionsManaging: Sendable {
  func fetchInteractions(familyUnitId: String) async throws -> [Interaction]
  func fetchInteractionsForUser(userId: String) async throws -> [Interaction]
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  func deleteInteraction(id: String) async throws
  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult
}

struct CascadeDeleteResult: Codable {
  let deletedInteractions: Int
  let deletedNotes: Int

  enum CodingKeys: String, CodingKey {
    case deletedInteractions = "deleted_interactions"
    case deletedNotes = "deleted_notes"
  }
}

// Features/Interactions/Services/InteractionsServiceImpl.swift
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InteractionsService")

final class InteractionsServiceImpl: InteractionsManaging {
  private let supabaseManager: SupabaseManager

  nonisolated init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchInteractions(familyUnitId: String) async throws -> [Interaction] {
    logger.info("Fetching interactions for family: \(familyUnitId)")

    let interactions: [Interaction] = try await supabaseManager.client
      .from("interactions")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .order("occurred_at", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(interactions.count) interactions")
    return interactions
  }

  func fetchInteractionsForUser(userId: String) async throws -> [Interaction] {
    logger.info("Fetching interactions for user: \(userId)")

    let interactions: [Interaction] = try await supabaseManager.client
      .from("interactions")
      .select()
      .eq("logged_by", value: userId)
      .order("occurred_at", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(interactions.count) interactions")
    return interactions
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    logger.info("Fetching schools for family: \(familyUnitId)")

    let schools: [School] = try await supabaseManager.client
      .from("schools")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value

    logger.info("Fetched \(schools.count) schools")
    return schools
  }

  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    guard !schoolIds.isEmpty else { return [] }

    logger.info("Fetching coaches for \(schoolIds.count) schools")

    let coaches: [Coach] = try await supabaseManager.client
      .from("coaches")
      .select()
      .in("school_id", values: schoolIds)
      .execute()
      .value

    logger.info("Fetched \(coaches.count) coaches")
    return coaches
  }

  func deleteInteraction(id: String) async throws {
    logger.info("Deleting interaction: \(id)")

    try await supabaseManager.client
      .from("interactions")
      .delete()
      .eq("id", value: id)
      .execute()

    logger.info("Deleted interaction: \(id)")
  }

  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult {
    logger.info("Cascade deleting interaction: \(id)")

    struct Response: Codable {
      let deleted: CascadeDeleteResult
    }

    let response: Response = try await supabaseManager.client.functions
      .invoke("cascade-delete-interaction", options: .init(
        body: ["interactionId": id]
      ))

    logger.info("Cascade deleted interaction: \(id)")
    return response.deleted
  }
}

// Mocks/MockInteractionsService.swift
final class MockInteractionsService: InteractionsManaging {
  var shouldSucceed = true
  var mockInteractions: [Interaction] = []
  var mockSchools: [School] = []
  var mockCoaches: [Coach] = []
  var deleteCallCount = 0
  var cascadeDeleteCallCount = 0

  func fetchInteractions(familyUnitId: String) async throws -> [Interaction] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockInteractions
  }

  func fetchInteractionsForUser(userId: String) async throws -> [Interaction] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockInteractions.filter { $0.loggedBy == userId }
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockSchools
  }

  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockCoaches.filter { schoolIds.contains($0.schoolId) }
  }

  func deleteInteraction(id: String) async throws {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    deleteCallCount += 1
    mockInteractions.removeAll { $0.id == id }
  }

  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    cascadeDeleteCallCount += 1
    mockInteractions.removeAll { $0.id == id }
    return CascadeDeleteResult(deletedInteractions: 1, deletedNotes: 2)
  }
}
```

**Verification:**
- Run build: All services compile
- Protocol conforms to Sendable
- Mock ready for testing

---

### Phase 3: ViewModel (1 hour)

**Goal:** Business logic, filtering, analytics, delete

**File to create:**
- `InteractionsListViewModel.swift`

**Implementation:**

```swift
// Features/Interactions/ViewModels/InteractionsListViewModel.swift
import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InteractionsListViewModel")

@MainActor
final class InteractionsListViewModel: ObservableObject {
  @Published var allInteractions: [Interaction] = []
  @Published var allSchools: [School] = []
  @Published var allCoaches: [Coach] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var filters = InteractionFilters()
  @Published var showDeleteConfirmation = false
  @Published var interactionToDelete: Interaction?
  @Published var isDeleting = false
  @Published var deleteErrorMessage: String?
  @Published var successMessage: String?
  @Published var showSuccessToast = false

  private let interactionsService: any InteractionsManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  // MARK: - Computed Properties

  var filteredInteractions: [Interaction] {
    var result = allInteractions

    // 1. Text search (subject + content)
    if !filters.searchText.isEmpty {
      let query = filters.searchText.lowercased()
      result = result.filter { interaction in
        (interaction.subject?.lowercased().contains(query) ?? false) ||
        (interaction.content?.lowercased().contains(query) ?? false)
      }
    }

    // 2. Type filter
    if let type = filters.type {
      result = result.filter { $0.type == type }
    }

    // 3. Direction filter
    if let direction = filters.direction {
      result = result.filter { $0.direction == direction }
    }

    // 4. Sentiment filter
    if let sentiment = filters.sentiment {
      result = result.filter { $0.sentiment == sentiment }
    }

    // 5. Time period filter
    if let period = filters.timePeriod {
      let cutoff = Calendar.current.date(byAdding: .day, value: -period.rawValue, to: Date()) ?? Date()
      result = result.filter { $0.displayDate >= cutoff }
    }

    // 6. Logged By filter (parents only)
    if let userId = filters.loggedBy {
      result = result.filter { $0.loggedBy == userId }
    }

    // Sort by date descending (newest first)
    return result.sorted { $0.displayDate > $1.displayDate }
  }

  var analytics: InteractionAnalytics {
    let filtered = filteredInteractions
    let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

    return InteractionAnalytics(
      totalCount: filtered.count,
      outboundCount: filtered.filter { $0.direction == .outbound }.count,
      inboundCount: filtered.filter { $0.direction == .inbound }.count,
      thisWeekCount: filtered.filter { $0.displayDate >= weekAgo }.count
    )
  }

  var schoolNameMap: [String: String] {
    Dictionary(uniqueKeysWithValues: allSchools.map { ($0.id, $0.name) })
  }

  var coachNameMap: [String: String] {
    Dictionary(uniqueKeysWithValues: allCoaches.map { ($0.id, $0.fullName) })
  }

  var activeFilterCount: Int {
    filters.activeFilterCount
  }

  var resultCount: Int {
    filteredInteractions.count
  }

  var isParent: Bool {
    authManager.user?.role == .parent
  }

  var isAthlete: Bool {
    authManager.user?.role == .athlete
  }

  // MARK: - Initialization

  nonisolated init(
    interactionsService: any InteractionsManaging = InteractionsServiceImpl(supabaseManager: .shared),
    familyManager: FamilyManager = .shared,
    authManager: any AuthManaging = AuthManager.shared
  ) {
    self.interactionsService = interactionsService
    self.familyManager = familyManager
    self.authManager = authManager
  }

  // MARK: - Data Loading

  func loadInteractions() async {
    guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
      logger.warning("No familyUnitId available")
      errorMessage = "Unable to load interactions. Please try again."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      // Load schools and coaches for name lookup
      let schools = try await interactionsService.fetchSchools(familyUnitId: familyUnitId)
      allSchools = schools

      let schoolIds = schools.map(\.id)
      allCoaches = try await interactionsService.fetchCoaches(schoolIds: schoolIds)

      // Load interactions based on role
      if isAthlete, let userId = authManager.user?.id {
        // Athletes see only their own interactions
        allInteractions = try await interactionsService.fetchInteractionsForUser(userId: userId)
        logger.info("Loaded \(self.allInteractions.count) interactions for athlete")
      } else {
        // Parents see all family interactions
        allInteractions = try await interactionsService.fetchInteractions(familyUnitId: familyUnitId)
        logger.info("Loaded \(self.allInteractions.count) interactions for family")
      }
    } catch {
      logger.error("Failed to load interactions: \(error.localizedDescription)")
      errorMessage = "Failed to load interactions: \(error.localizedDescription)"
    }
  }

  // MARK: - Delete

  func confirmDelete(_ interaction: Interaction) {
    interactionToDelete = interaction
    showDeleteConfirmation = true
  }

  func deleteInteraction() async {
    guard let interaction = interactionToDelete else { return }
    let interactionSubject = interaction.subject ?? interaction.type.displayName

    isDeleting = true
    deleteErrorMessage = nil
    successMessage = nil
    defer {
      isDeleting = false
      interactionToDelete = nil
      showDeleteConfirmation = false
    }

    do {
      try await interactionsService.deleteInteraction(id: interaction.id)
      allInteractions.removeAll { $0.id == interaction.id }
      logger.info("Deleted interaction: \(interactionSubject)")
      successMessage = "Interaction deleted"
      showSuccessToast = true
    } catch {
      logger.warning("Simple delete failed, attempting cascade: \(error.localizedDescription)")
      do {
        let result = try await interactionsService.cascadeDeleteInteraction(id: interaction.id)
        allInteractions.removeAll { $0.id == interaction.id }
        logger.info("Cascade deleted interaction: \(interactionSubject)")

        // Build detailed success message
        let totalDeleted = result.deletedInteractions + result.deletedNotes
        if totalDeleted > 0 {
          successMessage = "Interaction and \(totalDeleted) related record\(totalDeleted == 1 ? "" : "s") deleted"
        } else {
          successMessage = "Interaction deleted"
        }
        showSuccessToast = true
      } catch {
        logger.error("Cascade delete failed: \(error.localizedDescription)")
        deleteErrorMessage = "Failed to delete interaction. Please try again."
      }
    }
  }

  // MARK: - Filters

  func clearFilters() {
    filters = InteractionFilters()
  }

  // MARK: - Helpers

  func schoolName(for schoolId: String?) -> String? {
    guard let schoolId else { return nil }
    return schoolNameMap[schoolId] ?? "Unknown School"
  }

  func coachName(for coachId: String?) -> String? {
    guard let coachId else { return nil }
    return coachNameMap[coachId] ?? "Unknown Coach"
  }
}
```

**Verification:**
- Run build: ViewModel compiles
- No force unwraps
- All @Published on @MainActor

---

### Phase 4: UI Components (2 hours)

**Goal:** Reusable components for cards, filters, analytics

**Files to create:**
1. `InteractionCard.swift` - Individual interaction card
2. `InteractionAnalyticsCards.swift` - 4-card dashboard
3. `InteractionFilterBar.swift` - Filter controls
4. `InteractionEmptyState.swift` - Empty/no results states
5. `InteractionPrivacyNotice.swift` - Athletes only

**Implementation notes:**
- Follow CoachCardView pattern for InteractionCard
- Analytics cards in 2×2 grid (LazyVGrid)
- Filter bar horizontal scroll (like CoachFilterBar)
- Empty state with conditional CTA
- Privacy notice: Blue-50 background, info icon

**Key accessibility requirements:**
- All cards have proper labels
- Analytics cards: "{label}: {count}"
- Filter buttons: min 44pt touch targets
- Empty state CTA: clear label
- Privacy notice: readable by VoiceOver

---

### Phase 5: Main View (1 hour)

**Goal:** Assemble all components into InteractionsListView

**File to create:**
- `InteractionsListView.swift`

**Implementation pattern:**
- Follow CoachesListView structure
- Search bar at top
- Analytics cards (conditional: hide if empty)
- Filter bar
- Active filter chips (conditional)
- Results header
- List of cards OR empty state
- Pull-to-refresh
- Delete confirmation dialog
- Success toast

**Role-based rendering:**
- Athletes: Show privacy notice
- Athletes: Hide "Logged By" filter
- Parents: Show "Logged By" filter with options

---

### Phase 6: Testing (3 hours)

**Goal:** 80%+ coverage with TDD approach

**Test files to create:**
1. `InteractionsListViewModelTests.swift` (~50 tests)
2. `InteractionCardTests.swift` (~15 tests)
3. `InteractionAnalyticsCardsTests.swift` (~10 tests)
4. `InteractionsAccessibilityTests.swift` (~20 tests)

**ViewModel test categories:**
- ✅ Data loading (athlete vs parent)
- ✅ Filtering (all 6 filter types + combinations)
- ✅ Analytics computation
- ✅ Delete (simple + cascade)
- ✅ Error handling
- ✅ Empty states
- ✅ Role-based access

**Component test categories:**
- ✅ Card rendering
- ✅ Badge colors
- ✅ Date formatting
- ✅ Analytics calculations
- ✅ Filter interactions

**Accessibility test categories:**
- ✅ VoiceOver labels
- ✅ Touch targets
- ✅ Dynamic Type
- ✅ Semantic traits

---

### Phase 7: Integration & Code Review (1 hour)

**Goal:** Connect to navigation, run all tests, code review

**Tasks:**
1. Add InteractionsListView to TabView (if applicable)
2. Add navigation destination enum
3. Run all tests: `xcodebuild test ...`
4. Run code review agent
5. Fix any CRITICAL/HIGH issues
6. Verify accessibility with VoiceOver

---

## 4. Testing Strategy

### Unit Tests (ViewModel)

**InteractionsListViewModelTests.swift (~50 tests)**

```swift
// Sample test structure
final class InteractionsListViewModelTests: XCTestCase {
  var viewModel: InteractionsListViewModel!
  var mockService: MockInteractionsService!
  var mockFamilyManager: FamilyManager!
  var mockAuthManager: MockAuthManager!

  // MARK: - Data Loading Tests (8 tests)
  func testLoadInteractionsForAthlete_Success()
  func testLoadInteractionsForParent_Success()
  func testLoadInteractions_NoFamilyUnit_ShowsError()
  func testLoadInteractions_ServiceError_ShowsError()
  func testLoadInteractions_LoadsSchoolsAndCoaches()
  func testLoadInteractions_SetsLoadingState()

  // MARK: - Filtering Tests (20 tests)
  func testFilterBySearchText_Subject()
  func testFilterBySearchText_Content()
  func testFilterBySearchText_CaseInsensitive()
  func testFilterByType()
  func testFilterByDirection()
  func testFilterBySentiment()
  func testFilterByTimePeriod()
  func testFilterByLoggedBy()
  func testFilterCombination_TypeAndDirection()
  func testFilterCombination_AllFilters()
  func testClearFilters()
  func testActiveFilterCount()

  // MARK: - Analytics Tests (5 tests)
  func testAnalytics_TotalCount()
  func testAnalytics_OutboundCount()
  func testAnalytics_InboundCount()
  func testAnalytics_ThisWeekCount()
  func testAnalytics_UpdatesWithFilters()

  // MARK: - Delete Tests (5 tests)
  func testDeleteInteraction_Success()
  func testDeleteInteraction_CascadeSuccess()
  func testDeleteInteraction_Error()
  func testConfirmDelete_SetsInteractionToDelete()
  func testDeleteInteraction_RemovesFromList()

  // MARK: - Role-Based Tests (5 tests)
  func testIsParent_ReturnsTrue()
  func testIsAthlete_ReturnsTrue()
  func testLoadInteractions_AthleteSeesOwnOnly()
  func testLoadInteractions_ParentSeesAll()

  // MARK: - Helpers Tests (3 tests)
  func testSchoolName_Found()
  func testSchoolName_NotFound()
  func testCoachName_Found()
}
```

### Accessibility Tests

**InteractionsAccessibilityTests.swift (~20 tests)**

```swift
final class InteractionsAccessibilityTests: XCTestCase {
  // Analytics Cards
  func testAnalyticsCards_HaveAccessibilityLabels()
  func testAnalyticsCards_AnnounceValues()

  // Interaction Card
  func testInteractionCard_HasAccessibilityLabel()
  func testInteractionCard_IncludesTypeAndDirection()
  func testInteractionCard_IncludesSchoolAndCoach()
  func testInteractionCard_HasButtonTrait()

  // Filter Bar
  func testFilterButtons_HaveLabels()
  func testFilterButtons_Have44ptTouchTargets()

  // Privacy Notice
  func testPrivacyNotice_IsAccessible()

  // Empty State
  func testEmptyState_HasAccessibleCTA()

  // Dynamic Type
  func testInteractionCard_SupportsDynamicType()
  func testAnalyticsCards_SupportDynamicType()
}
```

---

## 5. Accessibility Compliance

### VoiceOver Requirements

**InteractionCard:**
- Label: "{type} {direction}, {subject}, with {coach} at {school}, {date}"
- Trait: `.isButton`
- Hint: "Tap to view details"

**Analytics Cards:**
- Label: "{metric name}: {count}"
- Trait: `.staticText`

**Filter Buttons:**
- Label: Descriptive (e.g., "Filter by type")
- Trait: `.isButton`
- Min 44pt touch target

**Privacy Notice:**
- Label: Full text content
- Trait: `.staticText`

### Dynamic Type Support

- All fonts: Semantic (.body, .headline, .caption)
- Icons: Scale with `@Environment(\.sizeCategory)`
- Button frames: `minHeight: 44, minWidth: 44`
- Flexible layouts: No fixed heights

---

## 6. Known Issues & Limitations

### From Spec

1. **No pagination:** Load all interactions at once (MVP acceptable)
2. **Export CSV/PDF:** Defer to Phase 3
3. **Attachment viewing:** Show count only, defer detail to Phase 3
4. **Real-time updates:** Simple fetch-on-load (no subscriptions)

### iOS-Specific

1. **Date formatting:** Use locale-aware `DateFormatter`
2. **Timezone:** Display in user's local timezone
3. **Filter persistence:** Filters reset on navigation away
4. **Analytics reactivity:** Recomputes on filter change

---

## 7. Definition of Done

### Functional Requirements

- [ ] All interactions load correctly (role-based)
- [ ] Analytics cards show accurate counts
- [ ] All 6 filters work independently and in combination
- [ ] Search filters subject and content
- [ ] Interaction cards display all required info
- [ ] Delete works with cascade fallback
- [ ] Pull-to-refresh re-fetches data
- [ ] Athletes see privacy notice
- [ ] Parents see "Logged By" filter
- [ ] Empty states render correctly

### Code Quality

- [ ] 80%+ test coverage
- [ ] All tests passing (538+ total)
- [ ] Zero build errors
- [ ] Zero warnings
- [ ] Code review passed (no CRITICAL/HIGH)

### Accessibility

- [ ] All VoiceOver labels present
- [ ] All touch targets 44pt minimum
- [ ] Dynamic Type supported
- [ ] Semantic traits applied
- [ ] Accessibility tests passing

### Documentation

- [ ] CLAUDE.md updated
- [ ] MEMORY.md updated
- [ ] Commit message descriptive
- [ ] HANDOFF document created

---

## 8. Risk Assessment

### Low Risk

- ✅ Models: Straightforward Codable structs
- ✅ Service: Pattern established (Coaches/Schools)
- ✅ ViewModel: Client-side filtering proven
- ✅ Components: Reuse existing patterns

### Medium Risk

- ⚠️ Role-based access: Requires careful testing (athlete vs parent)
- ⚠️ Analytics computation: Must update with filters
- ⚠️ Date parsing: ISO8601 with fallbacks

### Mitigation Strategies

1. **Role-based access:** Write tests first, mock both roles
2. **Analytics:** Use computed property, test edge cases
3. **Date parsing:** Static ISO8601DateFormatter, fallback to createdAt

---

## 9. Next Steps After Completion

### Phase 3: Add Interaction Form

- Implement interaction creation form
- File attachment upload
- Form validation
- Update coach `last_contact_date` on save

### Phase 4: Interaction Detail View

- Full interaction detail page
- Edit interaction
- View attachments
- Add follow-up reminders

---

## 10. Unresolved Questions

**None.** Spec is complete and web implementation verified.

---

## 11. Approval

**Plan reviewed by:** Claude Code
**Spec verified:** ✅ Yes
**Web implementation reference:** ✅ Available
**Ready for implementation:** ✅ Yes

**Estimated completion:** 3 days (solo) or 1.5 days (pair programming)

---

**Next action:** Approve this plan and begin Phase 1 (Models & Enums).
