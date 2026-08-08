# Action-Item Buttons + Learn More (iOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each Dashboard action-item (suggestion) a guided primary CTA and a Learn More help modal, let parents act on items in preview mode, and present items ordered by urgency.

**Architecture:** Edit the shared `ActionItemCard` (used by both `ActionItemsWidget` and `SuggestionsListView`). A pure `ActionItemCTA` enum maps `suggestion.actionType` → button; the card presents `AddSchoolView` / `AddInteractionView` in reusable sheets and a `SuggestionHelpModal` keyed by `ruleType`. Parent-preview gating is removed from `DashboardViewModel`. Suggestions are urgency-sorted at fetch.

**Tech Stack:** SwiftUI, Swift 6, `@Observable`/`@MainActor` MVVM, XCTest.

## Global Constraints

- Source path is double-nested: `TheRecruitingCompass/TheRecruitingCompass/…`. Tests: `TheRecruitingCompass/TheRecruitingCompassTests/…`.
- Xcode project uses `PBXFileSystemSynchronizedRootGroup` — new `.swift` files are auto-included. NEVER edit `.xcodeproj` or run `add_files_to_xcode.rb`.
- All user-facing copy uses `String(localized:)`.
- Every `@MainActor` class (production or test) MUST have `nonisolated deinit {}`. New `@MainActor XCTestCase` subclasses included.
- SwiftLint line length ≤ 120.
- Build/verify from `TheRecruitingCompass/`: `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`. Tests: add `-only-testing:TheRecruitingCompassTests` for unit-only.
- `SupabaseConfig.generated.swift` regenerates every build — NEVER commit its diff.
- Work happens on branch `feature/action-item-buttons` (already created; spec committed there).
- This plan covers iOS only. The dependent web endpoint fix (parent→athlete resolution in `dismiss`/`complete`) is a separate plan: `docs/superpowers/plans/2026-08-08-suggestions-endpoint-parent-resolution.md`. iOS unit tests mock the service, so they do not require the web fix.

---

### Task 1: Urgency sort

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/Suggestion.swift` (add `sortWeight` to `UrgencyLevel`)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift:253-279` (`fetchSuggestions` — sort both assignment sites)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/DashboardViewModelSuggestionSortTests.swift`

**Interfaces:**
- Produces: `Suggestion.UrgencyLevel.sortWeight: Int` (high=0, medium=1, low=2). `DashboardViewModel.suggestions` is ordered high→medium→low after any fetch, stable within an urgency.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DashboardViewModelSuggestionSortTests: XCTestCase {
  nonisolated deinit {}

  func test_urgencyLevel_sortWeight_ordersHighFirst() {
    XCTAssertLessThan(Suggestion.UrgencyLevel.high.sortWeight, Suggestion.UrgencyLevel.medium.sortWeight)
    XCTAssertLessThan(Suggestion.UrgencyLevel.medium.sortWeight, Suggestion.UrgencyLevel.low.sortWeight)
  }

  func test_sortedByUrgency_isStableWithinSameUrgency() {
    let input = [
      makeSuggestion(id: "a", urgency: .low),
      makeSuggestion(id: "b", urgency: .high),
      makeSuggestion(id: "c", urgency: .medium),
      makeSuggestion(id: "d", urgency: .high)
    ]
    let sorted = input.sorted { $0.urgency.sortWeight < $1.urgency.sortWeight }
    XCTAssertEqual(sorted.map(\.id), ["b", "d", "c", "a"])
  }

  private func makeSuggestion(id: String, urgency: Suggestion.UrgencyLevel) -> Suggestion {
    Suggestion(
      id: id, ruleType: "interaction-gap", message: "m", urgency: urgency,
      actionType: nil, relatedSchoolId: nil, dismissed: false, completed: false,
      pendingSurface: nil, surfacedAt: nil
    )
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/DashboardViewModelSuggestionSortTests`
Expected: FAIL to compile — `sortWeight` does not exist.

- [ ] **Step 3: Add `sortWeight` to `UrgencyLevel`**

In `Suggestion.swift`, inside `enum UrgencyLevel`, after `displayName`:

```swift
    /// Sort priority: high surfaces first.
    var sortWeight: Int {
      switch self {
      case .high: return 0
      case .medium: return 1
      case .low: return 2
      }
    }
```

- [ ] **Step 4: Sort in `fetchSuggestions`**

In `DashboardViewModel.fetchSuggestions()`, both places that assign `suggestions = result.suggestions` (the initial call ~L260 and the post-refresh retry ~L269) become:

```swift
      suggestions = result.suggestions.sorted { $0.urgency.sortWeight < $1.urgency.sortWeight }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/DashboardViewModelSuggestionSortTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/Suggestion.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/DashboardViewModelSuggestionSortTests.swift
git commit -m "feat: sort dashboard suggestions by urgency"
```

---

### Task 2: `ActionItemCTA` mapping

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/ActionItemCTA.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/ActionItemCTATests.swift`

**Interfaces:**
- Produces: `enum ActionItemCTA { case addSchool, logInteraction, none }`, `init(actionType: String?)`, `var label: String?` (nil for `.none`).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class ActionItemCTATests: XCTestCase {
  func test_addSchool_mapsToAddSchoolWithLabel() {
    let cta = ActionItemCTA(actionType: "add_school")
    XCTAssertEqual(cta, .addSchool)
    XCTAssertEqual(cta.label, "Add School")
  }

  func test_logInteraction_mapsToLogInteractionWithLabel() {
    let cta = ActionItemCTA(actionType: "log_interaction")
    XCTAssertEqual(cta, .logInteraction)
    XCTAssertEqual(cta.label, "Log Interaction")
  }

  func test_videoAndUnknownAndNil_mapToNoneWithNilLabel() {
    XCTAssertEqual(ActionItemCTA(actionType: "add_video"), .none)
    XCTAssertEqual(ActionItemCTA(actionType: "update_video"), .none)
    XCTAssertEqual(ActionItemCTA(actionType: "something_new"), .none)
    XCTAssertEqual(ActionItemCTA(actionType: nil), .none)
    XCTAssertNil(ActionItemCTA(actionType: nil).label)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/ActionItemCTATests`
Expected: FAIL to compile — `ActionItemCTA` undefined.

- [ ] **Step 3: Create `ActionItemCTA.swift`**

```swift
import Foundation

/// Maps a suggestion's `action_type` to the primary CTA shown on its card.
/// Video actions (`add_video`/`update_video`), unknown types, and nil have no
/// iOS CTA today — the card shows Learn More only (see Path B).
enum ActionItemCTA: Equatable {
  case addSchool
  case logInteraction
  case none

  init(actionType: String?) {
    switch actionType {
    case "add_school": self = .addSchool
    case "log_interaction": self = .logInteraction
    default: self = .none
    }
  }

  var label: String? {
    switch self {
    case .addSchool: return String(localized: "Add School")
    case .logInteraction: return String(localized: "Log Interaction")
    case .none: return nil
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/ActionItemCTATests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/ActionItemCTA.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/ActionItemCTATests.swift
git commit -m "feat: add ActionItemCTA action_type mapping"
```

---

### Task 3: `SuggestionHelpContent` (Learn More data)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/SuggestionHelpContent.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/SuggestionHelpContentTests.swift`

**Interfaces:**
- Produces: `struct SuggestionHelpContent { let title, whyItMatters: String; let howToComplete, coachesExpect: [String]; let timeline: String }` and `static func content(for ruleType: String) -> SuggestionHelpContent` (known key → its entry; unknown → generic fallback titled "Learn More").

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class SuggestionHelpContentTests: XCTestCase {
  func test_knownRuleType_returnsSpecificContent() {
    let c = SuggestionHelpContent.content(for: "school-list-building")
    XCTAssertEqual(c.title, "Build Your Target School List")
    XCTAssertFalse(c.howToComplete.isEmpty)
    XCTAssertFalse(c.coachesExpect.isEmpty)
  }

  func test_unknownRuleType_returnsGenericFallback() {
    let c = SuggestionHelpContent.content(for: "video-link-health")
    XCTAssertEqual(c.title, "Learn More")
    XCTAssertEqual(c.howToComplete, ["Focus on the suggested action above."])
  }

  func test_allSevenKnownKeysHaveEntries() {
    let keys = [
      "school-list-building", "showcase-attendance", "ncaa-registration",
      "formal-outreach", "official-visit", "missing-video", "interaction-gap"
    ]
    for key in keys {
      XCTAssertNotEqual(SuggestionHelpContent.content(for: key).title, "Learn More", "Missing entry for \(key)")
    }
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SuggestionHelpContentTests`
Expected: FAIL to compile — `SuggestionHelpContent` undefined.

- [ ] **Step 3: Create `SuggestionHelpContent.swift`**

Copy verbatim from web `components/Suggestion/SuggestionHelpModal.vue:185-333`. All strings wrapped in `String(localized:)`.

```swift
import Foundation

/// Static "Learn More" help copy for a suggestion, keyed by rule type.
/// Ported from web `components/Suggestion/SuggestionHelpModal.vue` helpContentMap.
struct SuggestionHelpContent {
  let title: String
  let whyItMatters: String
  let howToComplete: [String]
  let coachesExpect: [String]
  let timeline: String

  static func content(for ruleType: String) -> SuggestionHelpContent {
    map[ruleType] ?? fallback
  }

  private static let fallback = SuggestionHelpContent(
    title: String(localized: "Learn More"),
    whyItMatters: String(localized: "This action is important for your recruiting success. Follow the steps below to make progress."),
    howToComplete: [String(localized: "Focus on the suggested action above.")],
    coachesExpect: [String(localized: "Demonstrated effort and commitment to recruiting.")],
    timeline: String(localized: "Start as soon as possible.")
  )

  private static let map: [String: SuggestionHelpContent] = [
    "school-list-building": SuggestionHelpContent(
      title: String(localized: "Build Your Target School List"),
      whyItMatters: String(localized: "A comprehensive list of 20-30 target schools ensures you have options and reduces the risk of being left without a scholarship. Coaches also notice when athletes have done their research and have a genuine interest in their program."),
      howToComplete: [
        String(localized: "Research Division I, II, and III programs that fit your athletic and academic profile"),
        String(localized: "Use academic SAT/ACT standards and athletic rankings as filters"),
        String(localized: "Consider location, team culture, coaching style, and academics"),
        String(localized: "Aim for a balanced list: 5-7 reach schools, 10-15 match schools, 5-8 safety schools"),
        String(localized: "Add each school to your list in the app with priority ratings")
      ],
      coachesExpect: [
        String(localized: "Evidence that you've researched their program specifically (mention details in emails)"),
        String(localized: "A list that shows self-awareness about academic and athletic fit"),
        String(localized: "Regular updates as you narrow your choices")
      ],
      timeline: String(localized: "Complete by end of sophomore year. Refine throughout junior year.")
    ),
    "showcase-attendance": SuggestionHelpContent(
      title: String(localized: "Attend Summer Showcases"),
      whyItMatters: String(localized: "Showcases are primary recruiting events where coaches evaluate players in person. Attending 2-3 quality showcases per summer significantly increases your exposure and gives coaches the chance to see you play against top competition."),
      howToComplete: [
        String(localized: "Research showcase dates and locations for summer (April-August)"),
        String(localized: "Prioritize showcases where your target schools have coaches attending"),
        String(localized: "Register and pay fees early for better placement"),
        String(localized: "Perform well and log the event in your recruiting timeline"),
        String(localized: "Follow up with any coaches you connected with at the showcase")
      ],
      coachesExpect: [
        String(localized: "Attendance at 2-3 quality showcases per summer minimum"),
        String(localized: "Strong performance against elite competition"),
        String(localized: "Follow-up communication after the showcase")
      ],
      timeline: String(localized: "Plan and attend during summer between sophomore and junior year.")
    ),
    "ncaa-registration": SuggestionHelpContent(
      title: String(localized: "Register with NCAA Eligibility Center"),
      whyItMatters: String(localized: "NCAA registration is mandatory for Division I and II recruiting. It establishes your official academic transcript with the NCAA and confirms your eligibility. Without it, schools cannot proceed with recruiting or financial aid."),
      howToComplete: [
        String(localized: "Visit the NCAA Eligibility Center website (ncaa.org/eligibility-center)"),
        String(localized: "Create your account and register as a student-athlete"),
        String(localized: "Request your high school transcript be sent directly to the NCAA"),
        String(localized: "Report your SAT/ACT scores (they'll also receive official scores)"),
        String(localized: "Keep your registration active and updated throughout junior and senior year")
      ],
      coachesExpect: [
        String(localized: "Registration completed by junior year (ideally early)"),
        String(localized: "Official transcripts on file with the NCAA"),
        String(localized: "Test scores submitted before scholarship offers")
      ],
      timeline: String(localized: "Register during junior year. Begin process early to avoid delays.")
    ),
    "formal-outreach": SuggestionHelpContent(
      title: String(localized: "Begin Formal Coach Outreach"),
      whyItMatters: String(localized: "Coaches expect consistent communication from interested athletes. Monthly touchpoints keep you on their radar and demonstrate genuine interest. The more they hear from you, the more likely they'll remain engaged in recruiting you."),
      howToComplete: [
        String(localized: "Identify 10-15 priority schools (A and B tier)"),
        String(localized: "Write a professional recruiting email introducing yourself (one template, personalized for each coach)"),
        String(localized: "Send initial contact emails to coaches with game film link"),
        String(localized: "Log each interaction (email, call, conversation at event) in your timeline"),
        String(localized: "Aim for one touchpoint per month with each priority school"),
        String(localized: "Include updates about recent games, academic progress, or highlights")
      ],
      coachesExpect: [
        String(localized: "Initial contact with personalized message and film"),
        String(localized: "Regular updates (monthly or every 4-6 weeks minimum)"),
        String(localized: "Respectful, professional communication"),
        String(localized: "Demonstrated knowledge of their program")
      ],
      timeline: String(localized: "Begin in junior year spring. Maintain through senior year.")
    ),
    "official-visit": SuggestionHelpContent(
      title: String(localized: "Schedule Official Visits"),
      whyItMatters: String(localized: "Official visits are critical for late-stage recruiting (junior/senior year). They give coaches the chance to evaluate you academically and athletically at their campus, and they give you the chance to assess whether the school is truly a fit. Many scholarship decisions happen during or after official visits."),
      howToComplete: [
        String(localized: "Identify your top 3-5 schools based on fit and genuine interest"),
        String(localized: "Contact the coach to express interest in visiting"),
        String(localized: "Coordinate visit date (usually includes practice, meeting coaches, campus tour, academics meeting)"),
        String(localized: "Prepare questions about program, expectations, and culture"),
        String(localized: "Log the visit details and any conversations that occur"),
        String(localized: "Send a thank-you note to coaches after the visit")
      ],
      coachesExpect: [
        String(localized: "Genuine interest in the program (not just free trip)"),
        String(localized: "Preparation and thoughtful questions"),
        String(localized: "Follow-up communication and feedback after visit"),
        String(localized: "Commitment timeline (if asked)")
      ],
      timeline: String(localized: "Schedule during junior or senior year. Plan 2-3 visits per year.")
    ),
    "missing-video": SuggestionHelpContent(
      title: String(localized: "Create a Highlight Video"),
      whyItMatters: String(localized: "A highlight video is your #1 recruiting tool. Coaches use video to evaluate your skills, athleticism, and football intelligence. Without film, you severely limit your recruiting opportunities even if scouts see you in person."),
      howToComplete: [
        String(localized: "Compile 30-40 plays showcasing your best performances"),
        String(localized: "Include game film (not just highlights) to show consistency"),
        String(localized: "Add title card with your name, position, grade, and contact info"),
        String(localized: "Include both good and neutral plays (coaches want reality, not just highlights)"),
        String(localized: "Upload to YouTube, Vimeo, or dedicated recruiting platforms"),
        String(localized: "Update video annually with new highlights")
      ],
      coachesExpect: [
        String(localized: "Clean, well-edited video that's easy to watch"),
        String(localized: "Consistent performance across multiple plays"),
        String(localized: "Updated film each year")
      ],
      timeline: String(localized: "Complete by sophomore year. Update annually or after major competitions.")
    ),
    "interaction-gap": SuggestionHelpContent(
      title: String(localized: "Stay in Touch with Priority Schools"),
      whyItMatters: String(localized: "Out of sight, out of mind. Priority coaches have many athletes competing for their attention. Regular contact keeps you visible and shows coaches you're genuinely interested. Coaches notice athletes who maintain consistent communication."),
      howToComplete: [
        String(localized: "Identify which priority schools you haven't contacted in 3+ weeks"),
        String(localized: "Send an email update (game results, recent accomplishments, or just a check-in)"),
        String(localized: "Consider a phone call if you have a direct coach's number"),
        String(localized: "Attend their camps or showcases to connect in person"),
        String(localized: "Log each interaction in your timeline with the date")
      ],
      coachesExpect: [
        String(localized: "Consistent communication every 3-4 weeks minimum"),
        String(localized: "Personalized messages (not mass emails)"),
        String(localized: "Genuine updates about your season and progress")
      ],
      timeline: String(localized: "Maintain throughout junior and senior recruiting season.")
    )
  ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SuggestionHelpContentTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/SuggestionHelpContent.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/SuggestionHelpContentTests.swift
git commit -m "feat: add SuggestionHelpContent help copy (ported from web)"
```

---

### Task 4: `SuggestionHelpModal` view

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/SuggestionHelpModal.swift`

**Interfaces:**
- Consumes: `SuggestionHelpContent.content(for:)` (Task 3).
- Produces: `struct SuggestionHelpModal: View { let ruleType: String; let urgency: Suggestion.UrgencyLevel }` — a self-contained sheet (own `NavigationStack` + Done toolbar button via `@Environment(\.dismiss)`).

This is a pure presentation view with no independently testable logic (its data is covered by Task 3). No test step; verified by build + `#Preview`.

- [ ] **Step 1: Create `SuggestionHelpModal.swift`**

```swift
import SwiftUI

/// "Learn More" detail sheet for an action item, keyed by rule type.
struct SuggestionHelpModal: View {
  let ruleType: String
  let urgency: Suggestion.UrgencyLevel

  @Environment(\.dismiss) private var dismiss

  private var content: SuggestionHelpContent { SuggestionHelpContent.content(for: ruleType) }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          section(title: String(localized: "Why It Matters")) {
            Text(content.whyItMatters)
              .font(.body)
              .foregroundStyle(Color.primary)
          }

          section(title: String(localized: "How to Complete")) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(Array(content.howToComplete.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                  Text("\(index + 1).")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(urgency.color)
                  Text(step)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                }
              }
            }
          }

          section(title: String(localized: "What Coaches Expect")) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(content.coachesExpect, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(urgency.color)
                    .accessibilityHidden(true)
                  Text(item)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                }
              }
            }
          }

          section(title: String(localized: "Timeline")) {
            Text(content.timeline)
              .font(.subheadline)
              .foregroundStyle(Color.secondaryText)
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle(content.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "Done")) { dismiss() }
        }
      }
    }
  }

  @ViewBuilder
  private func section<Body: View>(title: String, @ViewBuilder content: () -> Body) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
        .foregroundStyle(Color.primary)
      content()
    }
  }
}

#Preview {
  SuggestionHelpModal(ruleType: "school-list-building", urgency: .medium)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/SuggestionHelpModal.swift
git commit -m "feat: add SuggestionHelpModal Learn More sheet"
```

---

### Task 5: Reusable add-item sheets

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemSheets.swift`

**Interfaces:**
- Consumes: `AddSchoolView`, `AddInteractionView`, `SchoolsServiceImpl`, `InteractionsServiceImpl`, `SchoolDestination`.
- Produces: `struct ActionItemAddSchoolSheet: View { let familyUnitId, userId: String }` and `struct ActionItemAddInteractionSheet: View { let familyUnitId, userId: String }` — each wraps its add view in its own `NavigationStack`.

This mirrors the existing `private struct DashboardAddSchoolSheet` in `DashboardView.swift:238-259`. No independently testable logic — verified by build. (Leave the existing `DashboardAddSchoolSheet` as-is; this task does not refactor `DashboardView`.)

**Naming note:** the names are `ActionItem`-prefixed to avoid a collision with the existing `struct AddSchoolSheet` in `Features/Events/Components/AddSchoolSheet.swift` (same app module — an unprefixed `AddSchoolSheet` is a redeclaration error). Do NOT rename or touch the Events file.

- [ ] **Step 1: Create `ActionItemSheets.swift`**

```swift
import SwiftUI

/// Presents the Add School flow in its own navigation stack (for action-item CTAs).
/// Mirrors DashboardView's DashboardAddSchoolSheet so it can be reused from the card.
struct ActionItemAddSchoolSheet: View {
  let familyUnitId: String
  let userId: String

  @State private var navigationPath = NavigationPath()

  var body: some View {
    NavigationStack(path: $navigationPath) {
      AddSchoolView(
        schoolsService: SchoolsServiceImpl(supabaseManager: .shared),
        familyUnitId: familyUnitId,
        userId: userId,
        navigationPath: $navigationPath
      )
      .navigationDestination(for: SchoolDestination.self) { destination in
        if case .detail(let schoolId) = destination {
          SchoolDetailView(schoolId: schoolId)
        }
      }
    }
  }
}

/// Presents the Log Interaction flow in its own navigation stack (for action-item CTAs).
struct ActionItemAddInteractionSheet: View {
  let familyUnitId: String
  let userId: String

  var body: some View {
    NavigationStack {
      AddInteractionView(
        interactionsService: InteractionsServiceImpl(supabaseManager: .shared),
        familyUnitId: familyUnitId,
        userId: userId
      )
    }
  }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemSheets.swift
git commit -m "feat: add reusable AddSchool/AddInteraction sheets"
```

---

### Task 6: Ungate parent-preview in `DashboardViewModel` + expose acting IDs

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift` (`dismissSuggestion` ~L281, `completeSuggestion` ~L294; add two computed props)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/DashboardViewModelParentActionTests.swift`

**Interfaces:**
- Produces: `DashboardViewModel.actingUserId: String`, `DashboardViewModel.currentFamilyUnitId: String`. `dismissSuggestion`/`completeSuggestion` no longer early-return in parent-preview.

**Note on testability:** these methods call `dashboardService`. Construct the VM with a mock `DashboardManaging` and a `FamilyManager` in preview mode. Check the existing test suite for the established mock — search `class MockDashboardService` / `DashboardManaging` conformances under `TheRecruitingCompassTests/`. Reuse that mock; if it records calls, assert the call happened. If no call-recording mock exists, add a minimal spy conforming to `DashboardManaging` in the test file that sets a `dismissCalled`/`completeCalled` flag.

- [ ] **Step 1: Write the failing test**

Adapt the mock type name to the existing suite (see note). Skeleton:

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DashboardViewModelParentActionTests: XCTestCase {
  nonisolated deinit {}

  func test_dismiss_inParentPreview_stillCallsService() async {
    let spy = SpyDashboardService()
    let vm = DashboardViewModel(
      dashboardService: spy,
      familyManager: FamilyManagerTestFactory.parentPreviewing()  // see note
    )
    await vm.dismissSuggestion("sug-1")
    XCTAssertTrue(spy.dismissCalled)
  }

  func test_complete_inParentPreview_stillCallsService() async {
    let spy = SpyDashboardService()
    let vm = DashboardViewModel(
      dashboardService: spy,
      familyManager: FamilyManagerTestFactory.parentPreviewing()
    )
    await vm.completeSuggestion("sug-1")
    XCTAssertTrue(spy.completeCalled)
  }
}
```

If the suite has no parent-preview factory, this test may instead assert the simpler invariant that `isParentPreviewMode` no longer blocks the call by using whatever `FamilyManager` seam the other `DashboardViewModel` tests already use. Match the existing test patterns — do not invent new infrastructure.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/DashboardViewModelParentActionTests`
Expected: FAIL — service not called because the current guard early-returns in preview mode (or compile error if helper names differ; align names first).

- [ ] **Step 3: Remove the guards + add computed IDs**

In `DashboardViewModel.dismissSuggestion`, delete the line:

```swift
    guard !isParentPreviewMode else { return }
```

Do the same in `completeSuggestion`. Add near the other computed properties (by `isParentPreviewMode`, ~L91):

```swift
  var actingUserId: String { authManager.user?.id ?? "" }
  var currentFamilyUnitId: String { familyManager.currentMember?.familyUnitId ?? "" }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/DashboardViewModelParentActionTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/DashboardViewModelParentActionTests.swift
git commit -m "feat: let parents dismiss/complete action items in preview mode"
```

---

### Task 7: Rebuild `ActionItemCard` with CTA + Learn More; update call sites

This task changes `ActionItemCard`'s signature, so its two call sites and the widget's preview must update in the same commit to keep the build green.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemCard.swift` (full rewrite of `body`, new props/state)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemsWidget.swift` (props + card call + preview)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift` (pass acting IDs + refresh into the widget)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Suggestions/Views/SuggestionsListView.swift` (card call)

**Interfaces:**
- Consumes: `ActionItemCTA` (Task 2), `SuggestionHelpModal` (Task 4), `ActionItemAddSchoolSheet`/`ActionItemAddInteractionSheet` (Task 5), `DashboardViewModel.actingUserId`/`currentFamilyUnitId` (Task 6).
- Produces: `ActionItemCard(suggestion:familyUnitId:userId:onDismiss:onComplete:onActionCompleted:)` — no `canDismissOrComplete`; Complete/Dismiss always shown.

- [ ] **Step 1: Rewrite `ActionItemCard.swift`**

```swift
import SwiftUI

struct ActionItemCard: View {
  let suggestion: Suggestion
  let familyUnitId: String
  let userId: String
  let onDismiss: () -> Void
  let onComplete: () -> Void
  /// Called after an add-school/add-interaction sheet is dismissed so the host can refresh.
  let onActionCompleted: () -> Void

  @State private var showHelp = false
  @State private var activeSheet: CardSheet?

  private enum CardSheet: Identifiable {
    case addSchool
    case addInteraction
    var id: Int { hashValue }
  }

  private var cta: ActionItemCTA { ActionItemCTA(actionType: suggestion.actionType) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 12) {
        Circle()
          .fill(suggestion.urgency.color)
          .frame(width: 8, height: 8)
          .padding(.top, 6)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(suggestion.urgency.displayName)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(suggestion.urgency.color.opacity(0.15))
            .foregroundStyle(suggestion.urgency.color)
            .clipShape(.rect(cornerRadius: 4))
            .accessibilityHidden(true)

          Text(suggestion.message)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Color.primary)
            .lineLimit(3)
        }

        Spacer()
      }

      actionRow
    }
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .sheet(isPresented: $showHelp) {
      SuggestionHelpModal(ruleType: suggestion.ruleType, urgency: suggestion.urgency)
    }
    .sheet(item: $activeSheet, onDismiss: onActionCompleted) { sheet in
      switch sheet {
      case .addSchool:
        ActionItemAddSchoolSheet(familyUnitId: familyUnitId, userId: userId)
      case .addInteraction:
        ActionItemAddInteractionSheet(familyUnitId: familyUnitId, userId: userId)
      }
    }
  }

  @ViewBuilder
  private var actionRow: some View {
    HStack(spacing: 16) {
      if let label = cta.label {
        Button(label) { presentCTA() }
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(suggestion.urgency.color)
          .foregroundStyle(Color.white)
          .clipShape(.rect(cornerRadius: 8))
          .accessibilityHint("Opens the screen to complete this action")
      }

      Button(String(localized: "Learn More")) { showHelp = true }
        .font(.subheadline)
        .foregroundStyle(Color.accentBlue)
        .accessibilityHint("Shows detailed guidance for this suggestion")

      Spacer()

      Button(action: onComplete) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(Color.accentBlue)
          .font(.title3)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "Complete suggestion"))
      .accessibilityHint("Mark this suggestion as done")

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(Color.gray)
          .font(.title3)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "Dismiss suggestion"))
      .accessibilityHint("Hide this suggestion without completing it")
    }
  }

  private func presentCTA() {
    switch cta {
    case .addSchool: activeSheet = .addSchool
    case .logInteraction: activeSheet = .addInteraction
    case .none: break
    }
  }
}
```

- [ ] **Step 2: Update `ActionItemsWidget.swift`**

Replace the `canDismissOrComplete` property with the acting IDs + a refresh closure, and update the card call and the preview:

```swift
struct ActionItemsWidget: View {
  let suggestions: [Suggestion]
  let pendingCount: Int
  let familyUnitId: String
  let userId: String
  let onDismiss: (String) -> Void
  let onComplete: (String) -> Void
  let onActionCompleted: () -> Void
```

Card call inside the `ForEach`:

```swift
          ForEach(suggestions.prefix(3)) { suggestion in
            ActionItemCard(
              suggestion: suggestion,
              familyUnitId: familyUnitId,
              userId: userId,
              onDismiss: { onDismiss(suggestion.id) },
              onComplete: { onComplete(suggestion.id) },
              onActionCompleted: onActionCompleted
            )
          }
```

Update the `#Preview` at the bottom: remove `canDismissOrComplete: true`, add `familyUnitId: "fam-1", userId: "user-1"` and `onActionCompleted: {}`.

- [ ] **Step 3: Update `DashboardView.swift` widget call**

Find where `ActionItemsWidget(...)` is constructed in `DashboardView` (it passes `suggestions`, `pendingCount`, `canDismissOrComplete`, `onDismiss`, `onComplete`). Replace `canDismissOrComplete:` with:

```swift
        familyUnitId: viewModel.currentFamilyUnitId,
        userId: viewModel.actingUserId,
```

and add after `onComplete:`:

```swift
        onActionCompleted: { Task { await viewModel.fetchDashboardData() } }
```

- [ ] **Step 4: Update `SuggestionsListView.swift` card call**

Replace the `ActionItemCard(...)` call (lines ~27-40) with:

```swift
          ActionItemCard(
            suggestion: suggestion,
            familyUnitId: viewModel.currentFamilyUnitId,
            userId: viewModel.actingUserId,
            onDismiss: { Task { await viewModel.dismissSuggestion(suggestion.id) } },
            onComplete: { Task { await viewModel.completeSuggestion(suggestion.id) } },
            onActionCompleted: { Task { await viewModel.fetchSuggestions() } }
          )
```

- [ ] **Step 5: Build to verify everything compiles**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED (no remaining references to `canDismissOrComplete`).

- [ ] **Step 6: Run the full Dashboard test slice**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests`
Expected: TEST SUCCEEDED (trust the passed/failed counts + exit code, not a grep).

- [ ] **Step 7: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemCard.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemsWidget.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Suggestions/Views/SuggestionsListView.swift
git commit -m "feat: action-item card CTA buttons + Learn More"
```

---

### Task 8: Full-suite verification

**Files:** none (verification only).

- [ ] **Step 1: Clean build + full unit suite**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests`
Expected: TEST SUCCEEDED, 0 failures. Baseline was ~3726 passing before this plan; new tests add to that. If the simulator stalls with `RBSRequestErrorDomain`/`NSPOSIXErrorDomain Code=3`, run `xcrun simctl shutdown all && killall -9 CoreSimulatorService` and retry.

- [ ] **Step 2: Confirm no stray `canDismissOrComplete` references**

Run: `cd TheRecruitingCompass/TheRecruitingCompass && grep -rn "canDismissOrComplete" . || echo "clean"`
Expected: `clean`

- [ ] **Step 3: Do NOT commit `SupabaseConfig.generated.swift`**

Run: `git status --short`
Verify `SupabaseConfig.generated.swift` (if modified by the build) is NOT staged. It regenerates every build; never commit its diff.

---

## Self-Review

**Spec coverage:**
- Primary CTA per action_type → Tasks 2, 5, 7. ✓
- `add_video`/`update_video` → no CTA → Task 2 (`.none`) + Task 7 (label nil hides button). ✓
- `log_interaction` opens Add Interaction → Task 5/7. (Spec's `relatedSchoolId` prefill dropped — no such capability exists in `AddInteractionView` today; noted below.) ✓ with scope note
- Learn More static content by rule_type → Tasks 3, 4, 7. ✓
- Keep Complete/Dismiss → Task 7. ✓
- Ungate parents (CTA + Complete + Dismiss) → Task 6 (VM) + Task 7 (card always shows all). ✓
- Urgency sort → Task 1. ✓
- Tests: action_type mapping (T2), parent-preview proceeds (T6), urgency sort (T1), help lookup + fallback (T3). ✓

**Deviation from spec (intentional):** spec said reuse `InteractionDestination.addWithSchool` to prefill `relatedSchoolId`. Investigation showed `AddInteractionView`/`AddInteractionViewModel` take no school parameter and the existing `.addWithSchool` case ignores the id. Prefill would be new scope (new VM init param). Dropped from this plan; `log_interaction` opens the plain Add Interaction form, matching current app behavior. Flag as a future enhancement.

**Placeholder scan:** Task 6's test names the mock/factory abstractly because the existing test-suite mock name must be matched, not invented — the step explicitly instructs reusing the established `DashboardManaging` mock and matching existing `FamilyManager` test seams. All other steps carry concrete code.

**Type consistency:** `ActionItemCard(suggestion:familyUnitId:userId:onDismiss:onComplete:onActionCompleted:)` is used identically in Task 7 Steps 2/4. `actingUserId`/`currentFamilyUnitId` defined in Task 6, consumed in Task 7. `ActionItemCTA`/`.label` consistent across Tasks 2 and 7.

## Open follow-ups (not in this plan)

- **Web endpoint fix** (parent→athlete resolution in dismiss/complete): separate plan, blocked on the shared web checkout freeing up. Until it ships, a parent's dismiss/complete round-trips to a no-op server-side (card reappears on next fetch); player accounts are unaffected.
- **`relatedSchoolId` prefill** for `log_interaction` — requires adding a preselected-school param to `AddInteractionView`/VM.
- **Video CTA** (`add_video`/`update_video`) — Path B.
