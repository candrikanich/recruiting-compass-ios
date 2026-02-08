# Dashboard Implementation Plan

**Project:** The Recruiting Compass iOS App
**Created:** February 8, 2026
**Status:** Ready for Implementation
**Estimated Time:** 8-10 hours (3 phases)

---

## Executive Summary

The dashboard is **85% complete** with all core UI, data models, and parent preview mode working. The main blockers are:
1. **Critical Bug:** Dashboard data fetch error (Supabase query failing)
2. **Missing Navigation:** Stat cards don't navigate to detail pages
3. **Missing Features:** Complete suggestion action, recruiting packet widget, at-a-glance summary

This plan focuses on fixing the critical bug first, then implementing navigation, then optional enhancements.

---

## Phase 1: Fix Critical Dashboard Bug (1-2 hours)

### 🔴 CRITICAL: Resolve Data Fetch Error

**Problem:** Dashboard displays error "Failed to load dashboard: The data couldn't be read because it is missing"

**Root Cause Analysis:**
- Supabase query is failing with decoding error
- Could be: missing tables, schema mismatch, RLS policy blocking, or missing data

**Action Steps:**

#### Step 1.1: Verify Supabase Table Schemas (30 min)
```bash
# Connect to Supabase project and verify tables exist:
- schools
- coaches
- interactions
- offers
- events
- performance_metrics
- activity_log
- suggestions
```

**Check each table schema matches Swift models:**
- Column names match CodingKeys (snake_case → camelCase)
- Data types are compatible (String, Int, Date formats)
- Required fields are NOT NULL in DB

**Example:** School.swift expects:
```swift
case familyUnitId = "family_unit_id"
case createdAt = "created_at"
case updatedAt = "updated_at"
```

#### Step 1.2: Verify RLS Policies (15 min)
```sql
-- Check RLS is enabled and policies exist for authenticated users
SELECT * FROM pg_policies WHERE tablename IN (
  'schools', 'coaches', 'interactions', 'offers',
  'events', 'performance_metrics', 'activity_log', 'suggestions'
);
```

Ensure policies allow:
- SELECT for authenticated users
- Proper filtering by user_id/family_unit_id

#### Step 1.3: Add Better Error Handling (30 min)

**File:** `TheRecruitingCompass/Features/Dashboard/Services/DashboardServiceImpl.swift`

```swift
@MainActor
func fetchStats(familyUnitId: String, userId: String) async throws -> DashboardStats {
  do {
    // Add logging
    print("🔍 Fetching dashboard stats for familyUnitId: \(familyUnitId), userId: \(userId)")

    async let schools = fetchSchools(familyUnitId: familyUnitId)
    async let offers = fetchOffers(userId: userId)
    async let interactions = fetchInteractions(userId: userId, limit: nil)

    let (schoolList, offerList, interactionList) = try await (schools, offers, interactions)

    print("✅ Fetched: \(schoolList.count) schools, \(offerList.count) offers, \(interactionList.count) interactions")

    // ... rest of logic
  } catch {
    print("❌ Dashboard fetch error: \(error)")
    print("❌ Error type: \(type(of: error))")
    if let decodingError = error as? DecodingError {
      print("❌ Decoding error details: \(decodingError)")
    }
    throw error
  }
}
```

#### Step 1.4: Add Mock Data Fallback for Development (30 min)

**File:** `TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift`

```swift
func fetchDashboardData() async {
  guard let userId = authManager.user?.id else {
    errorMessage = "User not authenticated"
    return
  }

  await familyManager.loadFamilyData()

  let targetUserId = familyManager.selectedAthleteId ?? userId
  let familyUnitId = familyManager.currentMember?.familyUnitId ?? userId

  isLoading = true
  errorMessage = nil

  defer { isLoading = false }

  do {
    let fetchedStats = try await dashboardService.fetchStats(
      familyUnitId: familyUnitId,
      userId: targetUserId
    )
    stats = fetchedStats
    lastUpdated = Date()

    // Continue with other fetches...
  } catch {
    errorMessage = "Failed to load dashboard: \(error.localizedDescription)"

    // ADD: Fall back to empty stats for development
    #if DEBUG
    print("⚠️ Using empty stats for development")
    stats = DashboardStats(
      coachCount: 0,
      schoolCount: 0,
      interactionCount: 0,
      totalOffers: 0,
      acceptedOffers: 0,
      aTierSchoolCount: 0,
      acceptanceRate: nil
    )
    #endif
  }
}
```

**Acceptance Criteria:**
- [ ] Dashboard loads without error (shows 0 counts if no data)
- [ ] Error messages are descriptive and helpful
- [ ] Empty state displays when no data exists
- [ ] Logging helps identify where query fails

---

## Phase 2: Implement Stat Card Navigation (2-3 hours)

### 🎯 Enable Tapping Stat Cards to Navigate

**Requirement:** Tapping a stat card navigates to corresponding list page

**Dependencies:** Need to create detail list pages first (or stub them)

#### Step 2.1: Create Navigation Stub Pages (1 hour)

**Create Files:**
```
TheRecruitingCompass/Features/
  Coaches/Views/CoachesListView.swift
  Schools/Views/SchoolsListView.swift
  Interactions/Views/InteractionsListView.swift
  Offers/Views/OffersListView.swift
```

**Template for each page:**
```swift
import SwiftUI

struct CoachesListView: View {
  var body: some View {
    List {
      Text("Coaches list coming soon")
    }
    .navigationTitle("Coaches")
    .navigationBarTitleDisplayMode(.large)
  }
}
```

#### Step 2.2: Add Navigation Enum (15 min)

**File:** `TheRecruitingCompass/Features/Dashboard/Models/DashboardDestination.swift`

```swift
import Foundation

enum DashboardDestination: String, Identifiable {
  case coaches
  case schools
  case interactions
  case offers
  case accepted
  case aTier

  var id: String { rawValue }

  var title: String {
    switch self {
    case .coaches: return "Coaches"
    case .schools: return "Schools"
    case .interactions: return "Interactions"
    case .offers: return "Offers"
    case .accepted: return "Accepted Offers"
    case .aTier: return "A-Tier Schools"
    }
  }
}
```

#### Step 2.3: Update StatCard to Support Navigation (30 min)

**File:** `TheRecruitingCompass/Features/Dashboard/Components/StatCard.swift`

```swift
struct StatCard: View {
  let title: String
  let count: Int
  let subtitle: String?
  let icon: String
  let gradientColors: [Color]
  let isEnabled: Bool
  let destination: DashboardDestination? // ADD THIS

  var body: some View {
    Button(action: {}) { // This will be wrapped in NavigationLink
      VStack(alignment: .leading, spacing: 12) {
        // ... existing code
      }
      .padding()
      .frame(maxWidth: .infinity, minHeight: 120)
      .background(
        LinearGradient(
          gradient: Gradient(colors: gradientColors),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .cornerRadius(12)
      .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
      .opacity(isEnabled ? 1.0 : 0.7)
    }
    .buttonStyle(PlainButtonStyle())
    .disabled(!isEnabled)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(count)")
    .accessibilityValue(subtitle ?? "")
    .accessibilityAddTraits(isEnabled ? [.isButton] : [])
    .accessibilityHint(isEnabled ? "Tap to view \(title.lowercased()) list" : "")
  }
}
```

#### Step 2.4: Update DashboardView with Navigation (1 hour)

**File:** `TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift`

```swift
// Add @State for navigation
@State private var selectedDestination: DashboardDestination?

var body: some View {
  NavigationStack {
    VStack(spacing: 0) {
      // ... existing code

      ScrollView {
        VStack(spacing: 24) {
          // ... existing sections

          statsCardsSection

          // ... rest of view
        }
      }
    }
    .navigationDestination(for: DashboardDestination.self) { destination in
      destinationView(for: destination)
    }
  }
}

private var statsCardsSection: some View {
  LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
    if let stats = viewModel.stats {
      NavigationLink(value: DashboardDestination.coaches) {
        StatCard(
          title: "Coaches",
          count: stats.coachCount,
          subtitle: nil,
          icon: "person.2.fill",
          gradientColors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
          isEnabled: true, // CHANGE TO TRUE
          destination: .coaches
        )
      }
      .buttonStyle(PlainButtonStyle())

      // Repeat for other 5 cards...
    }
  }
}

@ViewBuilder
private func destinationView(for destination: DashboardDestination) -> some View {
  switch destination {
  case .coaches:
    CoachesListView()
  case .schools:
    SchoolsListView()
  case .interactions:
    InteractionsListView()
  case .offers:
    OffersListView()
  case .accepted:
    OffersListView() // Same as offers, filtered by status
  case .aTier:
    SchoolsListView() // Same as schools, filtered by tier
  }
}
```

**Acceptance Criteria:**
- [ ] All 6 stat cards are tappable
- [ ] Tapping navigates to correct stub page
- [ ] Navigation title displays correctly
- [ ] Back button returns to dashboard
- [ ] VoiceOver announces tap hint

---

## Phase 3: Implement Missing Features (4-5 hours)

### 🎯 Feature 3.1: Complete Suggestion Action (1 hour)

#### Step 3.1.1: Add Complete Button to ActionItemCard

**File:** `TheRecruitingCompass/Features/Dashboard/Components/ActionItemsWidget.swift`

```swift
struct ActionItemCard: View {
  let suggestion: Suggestion
  let onDismiss: () -> Void
  let onComplete: () -> Void // ADD THIS

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(suggestion.urgency.color)
        .frame(width: 8, height: 8)
        .padding(.top, 6)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(suggestion.title)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(suggestion.description)
          .font(.caption)
          .foregroundColor(Color.secondaryText)
          .lineLimit(2)
      }

      Spacer()

      // ADD: Complete button
      Button(action: onComplete) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(Color.accentBlue)
      }
      .buttonStyle(PlainButtonStyle())
      .accessibilityLabel("Complete suggestion")

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .foregroundColor(Color.gray)
      }
      .buttonStyle(PlainButtonStyle())
      .accessibilityLabel("Dismiss suggestion")
    }
    // ... rest of styling
  }
}
```

#### Step 3.1.2: Add Complete Method to DashboardService

**File:** `TheRecruitingCompass/Features/Dashboard/Services/DashboardManaging.swift`

```swift
protocol DashboardManaging: Sendable {
  // ... existing methods
  func completeSuggestion(id: String) async throws // ADD THIS
}
```

**File:** `TheRecruitingCompass/Features/Dashboard/Services/DashboardServiceImpl.swift`

```swift
@MainActor
func completeSuggestion(id: String) async throws {
  try await supabaseManager.client
    .from("suggestions")
    .update(["status": "completed"])
    .eq("id", value: id)
    .execute()
}
```

#### Step 3.1.3: Wire Up in ViewModel

**File:** `TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift`

```swift
func completeSuggestion(_ id: String) async {
  do {
    try await dashboardService.completeSuggestion(id: id)
    suggestions.removeAll { $0.id == id }
  } catch {
    errorMessage = "Failed to complete suggestion"
  }
}
```

**Acceptance Criteria:**
- [ ] "Complete" button appears on all suggestions
- [ ] Tapping complete removes suggestion from list
- [ ] API call updates suggestion status
- [ ] Error handling works

---

### 🎯 Feature 3.2: At-a-Glance Summary Widget (2-3 hours)

#### Step 3.2.1: Create Computed Properties in ViewModel

**File:** `TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift`

```swift
// ADD: Computed properties for At-a-Glance
var schoolsWithOffers: Int {
  guard let stats = stats else { return 0 }
  // Calculate unique school IDs from offers
  let schoolIds = Set(allOffers.compactMap { $0.schoolId })
  return schoolIds.count
}

var schoolsWithOffersPercentage: String {
  guard let stats = stats, stats.schoolCount > 0 else { return "0%" }
  let percentage = Double(schoolsWithOffers) / Double(stats.schoolCount) * 100
  return String(format: "%.0f%%", percentage)
}

var avgCoachResponsiveness: Double {
  // Calculate based on interaction response times
  // This requires interaction.responseTime field or similar logic
  // Placeholder for now:
  return 0.75 // 75%
}

var avgCoachResponsivenessFormatted: String {
  String(format: "%.0f%%", avgCoachResponsiveness * 100)
}

var avgCoachResponsivenessColor: Color {
  if avgCoachResponsiveness >= 0.75 {
    return .green
  } else if avgCoachResponsiveness >= 0.50 {
    return .warningOrange
  } else {
    return .errorRed
  }
}

var interactionsThisMonth: Int {
  let calendar = Calendar.current
  let now = Date()
  return allInteractions.filter { interaction in
    guard let date = ISO8601DateFormatter().date(from: interaction.interactionDate) else {
      return false
    }
    return calendar.isDate(date, equalTo: now, toGranularity: .month)
  }.count
}

var daysUntilGraduation: Int? {
  // Requires user.graduationDate field
  // Placeholder for now:
  guard let gradDate = authManager.user?.graduationDate else { return nil }
  let calendar = Calendar.current
  let now = Date()
  let components = calendar.dateComponents([.day], from: now, to: gradDate)
  return components.day
}

var daysUntilGraduationFormatted: String {
  guard let days = daysUntilGraduation else { return "--" }
  return "\(days)"
}
```

#### Step 3.2.2: Create AtAGlanceSummary Component

**File:** `TheRecruitingCompass/Features/Dashboard/Components/AtAGlanceSummary.swift`

```swift
import SwiftUI

struct AtAGlanceSummary: View {
  let schoolsWithOffers: String
  let avgCoachResponsiveness: String
  let avgResponsivenessColor: Color
  let interactionsThisMonth: Int
  let daysUntilGraduation: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("At a Glance")
        .font(.headline)

      Divider()

      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
      ], spacing: 16) {
        MetricCard(
          title: "Schools with Offers",
          value: schoolsWithOffers,
          color: .accentBlue
        )

        MetricCard(
          title: "Avg Coach Responsiveness",
          value: avgCoachResponsiveness,
          color: avgResponsivenessColor
        )

        MetricCard(
          title: "Interactions This Month",
          value: "\(interactionsThisMonth)",
          color: .accentBlue
        )

        MetricCard(
          title: "Days Until Graduation",
          value: daysUntilGraduation,
          color: .accentBlue
        )
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct MetricCard: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(value)
        .font(.system(size: 24, weight: .bold))
        .foregroundColor(color)

      Text(title)
        .font(.caption)
        .foregroundColor(Color.secondaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value)")
  }
}
```

#### Step 3.2.3: Add to DashboardView

**File:** `TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift`

```swift
private var chartsAndDataSection: some View {
  VStack(spacing: 16) {
    // ... existing widgets

    // ADD: At-a-Glance Summary
    if !viewModel.isEmpty {
      AtAGlanceSummary(
        schoolsWithOffers: viewModel.schoolsWithOffersPercentage,
        avgCoachResponsiveness: viewModel.avgCoachResponsivenessFormatted,
        avgResponsivenessColor: viewModel.avgCoachResponsivenessColor,
        interactionsThisMonth: viewModel.interactionsThisMonth,
        daysUntilGraduation: viewModel.daysUntilGraduationFormatted
      )
    }
  }
}
```

**Acceptance Criteria:**
- [ ] 4 metric cards display in 2x2 grid
- [ ] Values compute correctly
- [ ] Color logic for responsiveness works
- [ ] Graduation countdown displays or shows "--"
- [ ] VoiceOver announces values

---

### 🎯 Feature 3.3: Show More Suggestions (30 min)

**Option 1: Navigate to Full List Page**

**File:** `TheRecruitingCompass/Features/Suggestions/Views/SuggestionsListView.swift`

```swift
import SwiftUI

struct SuggestionsListView: View {
  let suggestions: [Suggestion]
  let onDismiss: (String) -> Void
  let onComplete: (String) -> Void

  var body: some View {
    List(suggestions) { suggestion in
      ActionItemCard(
        suggestion: suggestion,
        onDismiss: { onDismiss(suggestion.id) },
        onComplete: { onComplete(suggestion.id) }
      )
    }
    .navigationTitle("Action Items")
    .navigationBarTitleDisplayMode(.large)
  }
}
```

**Update DashboardView:**
```swift
if suggestions.count > 3 {
  NavigationLink(value: SuggestionsDestination.all) {
    Text("Show \(suggestions.count - 3) more")
      .font(.caption)
      .foregroundColor(Color.accentBlue)
  }
}
```

**Acceptance Criteria:**
- [ ] "Show more" navigates to full suggestions list
- [ ] All suggestions display
- [ ] Dismiss/complete work from list page

---

### 🎯 Feature 3.4: Recruiting Packet Widget (DEFER TO PHASE 5?)

**Recommendation:** Defer this to Phase 5 per spec notes. It requires:
- Complex HTML generation
- Email composition UI (MFMailComposeViewController)
- Backend API endpoints
- Significant testing

**If required for MVP, estimate:** 3-4 hours

---

## Phase 4: Testing & Polish (1-2 hours)

### 🧪 Testing Checklist

#### Unit Tests
- [ ] Test new ViewModel computed properties
- [ ] Test completeSuggestion API call
- [ ] Test navigation state management
- [ ] Test At-a-Glance calculations

#### Integration Tests
- [ ] Dashboard loads with real Supabase data
- [ ] Stat cards navigate correctly
- [ ] Parent preview mode switches athletes
- [ ] Quick tasks persist correctly

#### Accessibility Tests
- [ ] VoiceOver announces all new components
- [ ] Dynamic Type scales correctly
- [ ] Color contrast passes WCAG AA
- [ ] Touch targets are 44pt minimum

#### Manual Testing
- [ ] Test on iPhone SE, iPhone 15, iPad
- [ ] Test with 0 data (empty state)
- [ ] Test with large datasets (100+ items)
- [ ] Test pull-to-refresh
- [ ] Test error scenarios

---

## Success Criteria

### MVP Complete When:
- ✅ Dashboard loads without errors
- ✅ All 6 stat cards display and navigate
- ✅ Suggestions can be dismissed or completed
- ✅ Quick tasks work and persist
- ✅ Parent preview mode works
- ✅ Empty states display correctly
- ✅ Error handling works
- ✅ Pull-to-refresh works
- ✅ Accessibility passes audit
- ✅ Tests pass (unit + integration)

### Optional Enhancements:
- ⚠️ At-a-Glance Summary
- ⚠️ Show More Suggestions
- ⚠️ Recruiting Packet Widget (defer to Phase 5)
- ⚠️ Parent View Logging (defer to Phase 5)

---

## Implementation Order

**Day 1 (4-5 hours):**
1. Fix dashboard data fetch bug (Phase 1)
2. Implement stat card navigation (Phase 2)

**Day 2 (3-4 hours):**
3. Add complete suggestion action
4. Add At-a-Glance Summary (if desired)
5. Testing and polish

**Total:** 8-10 hours across 2 days

---

## Risk Assessment

### Low Risk
- Stat card navigation (straightforward NavigationLink)
- Complete suggestion action (similar to dismiss)
- At-a-Glance Summary (UI component with computed props)

### Medium Risk
- Dashboard data fetch bug (requires Supabase debugging)
- At-a-Glance computed properties (requires correct data)

### High Risk (Deferred)
- Recruiting Packet Widget (complex, needs backend)
- Parent View Logging (needs backend endpoint)

---

## Next Steps

1. **Review this plan with team**
2. **Confirm MVP priorities:**
   - Is At-a-Glance Summary required?
   - Should recruiting packet be deferred?
3. **Start with Phase 1 (fix critical bug)**
4. **Proceed to Phase 2 (navigation)**
5. **Evaluate Phase 3 features based on priorities**

---

## Questions for Team

1. **API vs Direct Queries:** Should iOS use `/api/suggestions` or direct Supabase queries?
2. **Recruiting Packet:** Defer to Phase 5 or implement now?
3. **At-a-Glance:** Required for MVP?
4. **Parent View Logging:** Required for MVP or defer?
5. **Detail List Pages:** Should we fully implement or stub for now?

---

## Sign-Off

**Created by:** Claude Code
**Date:** February 8, 2026
**Status:** Ready for Review
**Estimated Time:** 8-10 hours (3 phases)
**Recommendation:** Start with Phase 1 (critical bug fix) immediately
