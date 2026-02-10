# Interactions List - Completion Plan

**Created:** February 9, 2026
**Status:** 95% Complete - Missing Navigation & Accessibility Tests
**Spec:** `iOS_SPEC_Phase2_InteractionsList.md`

---

## Current Status

### ✅ Completed (95%)
- All models, services, viewmodels, views, components
- 30/31 ViewModel tests passing
- Filtering, analytics, role-based access all working
- Delete with cascade fallback implemented

### ❌ Remaining Work (5%)
1. Navigation to interaction detail
2. Navigation to add interaction
3. Accessibility tests for components
4. Fix failing cascade delete test

---

## Phase 1: Fix Failing Test (30 min)

### Task 1.1: Fix `testDeleteInteraction_CascadeSuccess()`
**File:** `TheRecruitingCompassTests/Features/Interactions/ViewModels/InteractionsListViewModelTests.swift`

**Current Issue:**
- Test is failing (likely async timing or assertion issue)

**Steps:**
1. Read the failing test
2. Identify root cause (async await, mock setup, assertion)
3. Fix the test to properly verify cascade delete behavior
4. Run tests to verify fix

**Acceptance Criteria:**
- [ ] Test passes consistently
- [ ] No regressions in other tests
- [ ] Build status: CLEAN

---

## Phase 2: Add Navigation Support (1-2 hours)

### Task 2.1: Define Navigation Routes
**Files to Create/Modify:**
- `TheRecruitingCompass/Core/Navigation/NavigationRoute.swift` (or similar)

**Steps:**
1. Add `interactionDetail(interactionId: String)` route
2. Add `addInteraction` route
3. Update navigation coordinator if needed

### Task 2.2: Create Interaction Detail View (Placeholder)
**File:** `Features/Interactions/Views/InteractionDetailView.swift`

**Spec Reference:** Not in current spec (Phase 3 feature)

**Implementation:**
```swift
struct InteractionDetailView: View {
  let interactionId: String

  var body: some View {
    VStack {
      Text("Interaction Detail")
        .font(.largeTitle)
      Text("ID: \(interactionId)")
        .font(.caption)
        .foregroundColor(.secondary)

      Spacer()

      Text("📝 Full detail view coming in Phase 3")
        .font(.headline)
        .foregroundColor(.secondary)
    }
    .navigationTitle("Interaction Detail")
    .navigationBarTitleDisplayMode(.inline)
  }
}
```

**Acceptance Criteria:**
- [ ] Placeholder view displays interaction ID
- [ ] Back navigation works correctly
- [ ] No build errors

### Task 2.3: Create Add Interaction View (Placeholder)
**File:** `Features/Interactions/Views/AddInteractionView.swift`

**Spec Reference:** Phase 3 feature (out of scope for this spec)

**Implementation:**
```swift
struct AddInteractionView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Image(systemName: "plus.bubble.fill")
          .font(.system(size: 64))
          .foregroundColor(.blue)

        Text("Log Interaction")
          .font(.largeTitle)
          .fontWeight(.bold)

        Text("Full interaction logging form coming in Phase 3")
          .font(.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding()
      }
      .navigationTitle("Log Interaction")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}
```

**Acceptance Criteria:**
- [ ] Placeholder view displays
- [ ] Cancel button dismisses sheet
- [ ] No build errors

### Task 2.4: Wire Up Navigation in InteractionsListView
**File:** `Features/Interactions/Views/InteractionsListView.swift`

**Changes:**
1. Add `@State private var selectedInteractionId: String?`
2. Add `@State private var showAddInteraction = false`
3. Replace TODO comments with navigation actions

**Implementation:**
```swift
// Card tap (line 137)
Button {
  selectedInteractionId = interaction.id
} label: {
  InteractionCard(...)
}
.navigationDestination(item: $selectedInteractionId) { id in
  InteractionDetailView(interactionId: id)
}

// Toolbar button (line 49)
Button {
  showAddInteraction = true
} label: {
  Image(systemName: "plus")
    .frame(minWidth: 44, minHeight: 44)
}
.sheet(isPresented: $showAddInteraction) {
  AddInteractionView()
}
```

**Acceptance Criteria:**
- [ ] Tapping interaction card navigates to detail view
- [ ] Tapping "+" button presents add interaction sheet
- [ ] Navigation state resets correctly
- [ ] All existing functionality still works

---

## Phase 3: Accessibility Tests (2-3 hours)

### Task 3.1: Create InteractionCardAccessibilityTests
**File:** `TheRecruitingCompassTests/Accessibility/InteractionCardAccessibilityTests.swift`

**Spec Reference:** Section 6 (Accessibility)

**Tests to Implement:**
```swift
@MainActor
final class InteractionCardAccessibilityTests: XCTestCase {
  // 1. Type icon should be hidden (decorative)
  func testTypeIcon_IsHidden()

  // 2. Card should announce comprehensive label
  func testCard_HasComprehensiveAccessibilityLabel()
  // "{type} {direction}, {subject}, with {coach} at {school}, {date}"

  // 3. Direction badge should have proper label
  func testDirectionBadge_HasAccessibilityLabel()

  // 4. Sentiment badge should have proper label
  func testSentimentBadge_HasAccessibilityLabel()

  // 5. Attachment indicator should announce count
  func testAttachmentIndicator_AnnouncesCount()

  // 6. Date icon should be hidden (decorative)
  func testDateIcon_IsHidden()

  // 7. Card hit target is at least 44pt
  func testCard_MeetsMinimumTouchTarget()

  // 8. Card supports Dynamic Type scaling
  func testCard_SupportsDynamicType()
}
```

**Acceptance Criteria:**
- [ ] 8+ accessibility tests passing
- [ ] VoiceOver labels verified
- [ ] Decorative icons hidden
- [ ] Touch targets verified (44pt+)

### Task 3.2: Create InteractionAnalyticsCardsAccessibilityTests
**File:** `TheRecruitingCompassTests/Accessibility/InteractionAnalyticsCardsAccessibilityTests.swift`

**Tests to Implement:**
```swift
@MainActor
final class InteractionAnalyticsCardsAccessibilityTests: XCTestCase {
  // 1. Total card announces "{count} total interactions"
  func testTotalCard_HasAccessibilityLabel()

  // 2. Outbound card announces "{count} outbound interactions"
  func testOutboundCard_HasAccessibilityLabel()

  // 3. Inbound card announces "{count} inbound interactions"
  func testInboundCard_HasAccessibilityLabel()

  // 4. This Week card announces "{count} interactions this week"
  func testThisWeekCard_HasAccessibilityLabel()

  // 5. All card icons are hidden (decorative)
  func testCardIcons_AreHidden()

  // 6. Cards support Dynamic Type
  func testCards_SupportDynamicType()
}
```

**Acceptance Criteria:**
- [ ] 6+ accessibility tests passing
- [ ] Analytics cards properly labeled

### Task 3.3: Create InteractionFilterBarAccessibilityTests
**File:** `TheRecruitingCompassTests/Accessibility/InteractionFilterBarAccessibilityTests.swift`

**Tests to Implement:**
```swift
@MainActor
final class InteractionFilterBarAccessibilityTests: XCTestCase {
  // 1. Type filter button has label and hint
  func testTypeFilterButton_HasAccessibilityLabelAndHint()

  // 2. Direction filter button has label and hint
  func testDirectionFilterButton_HasAccessibilityLabelAndHint()

  // 3. Sentiment filter button has label and hint
  func testSentimentFilterButton_HasAccessibilityLabelAndHint()

  // 4. Time period filter button has label and hint
  func testTimePeriodFilterButton_HasAccessibilityLabelAndHint()

  // 5. Logged By filter button has label and hint (parents only)
  func testLoggedByFilterButton_HasAccessibilityLabelAndHint()

  // 6. Filter buttons have 44pt touch targets
  func testFilterButtons_MeetMinimumTouchTarget()
}
```

**Acceptance Criteria:**
- [ ] 6+ accessibility tests passing
- [ ] All filter buttons properly labeled
- [ ] Touch targets verified

### Task 3.4: Create InteractionPrivacyNoticeAccessibilityTests
**File:** `TheRecruitingCompassTests/Accessibility/InteractionPrivacyNoticeAccessibilityTests.swift`

**Tests to Implement:**
```swift
@MainActor
final class InteractionPrivacyNoticeAccessibilityTests: XCTestCase {
  // 1. Privacy notice has accessibility label
  func testPrivacyNotice_HasAccessibilityLabel()

  // 2. Info icon is hidden (decorative)
  func testInfoIcon_IsHidden()

  // 3. Notice has informational trait
  func testPrivacyNotice_HasInformationalTrait()

  // 4. Notice supports Dynamic Type
  func testPrivacyNotice_SupportsDynamicType()
}
```

**Acceptance Criteria:**
- [ ] 4+ accessibility tests passing
- [ ] Privacy notice properly announced

### Task 3.5: Create InteractionEmptyStateAccessibilityTests
**File:** `TheRecruitingCompassTests/Accessibility/InteractionEmptyStateAccessibilityTests.swift`

**Tests to Implement:**
```swift
@MainActor
final class InteractionEmptyStateAccessibilityTests: XCTestCase {
  // 1. Empty icon is hidden (decorative)
  func testEmptyIcon_IsHidden()

  // 2. Title and subtitle properly labeled
  func testTitleAndSubtitle_HaveProperLabels()

  // 3. CTA button has label and hint
  func testCTAButton_HasAccessibilityLabelAndHint()

  // 4. CTA button has 44pt touch target
  func testCTAButton_MeetsMinimumTouchTarget()
}
```

**Acceptance Criteria:**
- [ ] 4+ accessibility tests passing
- [ ] Empty state properly announced

---

## Phase 4: Final Verification (30 min)

### Task 4.1: Run All Tests
```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Acceptance Criteria:**
- [ ] All tests passing (100%)
- [ ] No build errors or warnings
- [ ] No test failures

### Task 4.2: Manual VoiceOver Testing
**Steps:**
1. Enable VoiceOver (Cmd+F5 in Simulator)
2. Navigate through interactions list
3. Verify all elements are properly announced
4. Test filter controls
5. Test analytics cards
6. Test privacy notice
7. Test empty states

**Acceptance Criteria:**
- [ ] All interactive elements reachable
- [ ] Labels are clear and comprehensive
- [ ] Decorative icons are not announced
- [ ] Navigation flows work correctly

### Task 4.3: Dynamic Type Testing
**Steps:**
1. Settings → Accessibility → Display & Text Size → Larger Text
2. Test at various sizes (Small, Large, AX1, AX5)
3. Verify layouts don't break
4. Verify button touch targets remain 44pt+

**Acceptance Criteria:**
- [ ] Text scales correctly at all sizes
- [ ] No layout overflow or clipping
- [ ] Touch targets remain accessible
- [ ] Cards maintain readability

### Task 4.4: Update Documentation
**Files to Update:**
- `MEMORY.md` - Mark interactions feature 100% complete
- `CLAUDE.md` - Update completed screens list
- `README.md` - Update feature status

**Acceptance Criteria:**
- [ ] Documentation reflects 100% completion
- [ ] Next steps updated

---

## Estimated Timeline

| Phase | Time Estimate | Priority |
|-------|---------------|----------|
| Phase 1: Fix Test | 30 min | HIGH |
| Phase 2: Navigation | 1-2 hours | HIGH |
| Phase 3: Accessibility Tests | 2-3 hours | MEDIUM |
| Phase 4: Verification | 30 min | HIGH |
| **TOTAL** | **4-6 hours** | - |

---

## Success Criteria (Spec 100% Complete)

- [x] All models match spec ✅
- [x] All services match spec ✅
- [x] All components match spec ✅
- [x] ViewModel tests 100% passing ⚠️ (30/31)
- [ ] Navigation to detail working
- [ ] Navigation to add interaction working
- [ ] Accessibility tests 100% passing
- [ ] Manual VoiceOver testing verified
- [ ] Dynamic Type testing verified
- [ ] Build: CLEAN
- [ ] All tests: PASSING

---

## Notes

### Out of Scope (Phase 3 Features)
- Interaction detail view (full implementation)
- Add/Edit interaction form
- Attachment viewing
- Export CSV/PDF functionality
- Real-time updates

### Deferred for Later
- Logged By filter: Full athlete name lookup (currently uses user IDs)
- Attachment preview thumbnails
- Interaction sharing/export

---

## Dependencies

- FamilyManager (role-based access)
- AuthManager (current user)
- InteractionsServiceImpl (Supabase integration)
- Shared components (FilteredResultsHeader, LoadingStateView, ToastModifier)

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Navigation requires coordinator pattern | Medium | Use simple NavigationDestination for MVP |
| Accessibility tests require UI testing | Low | Use ViewInspector or accessibility API |
| Cascade delete test flaky | Low | Fix async timing in test |

---

**Created by:** Claude Code
**For Session:** February 9, 2026
**Status:** Ready for implementation
