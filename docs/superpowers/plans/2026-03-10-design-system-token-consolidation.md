# Design System Token Consolidation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Establish a semantic color vocabulary on iOS matching the web app exactly, introduce a typed `BadgeColor` enum, fix critical color mismatches (`PriorityTier`, `SchoolStatus`, etc.), add skeleton loading views with reduced motion support, and write four `docs/design/` spec files.

**Architecture:** Three phases — (1) Foundation: `AppColors` brand palette + semantic layer + `BadgeColor` enum + `BadgeView` type change; (2) Call site sweep: update all model types that return `Color` for semantic status + dependent views; (3) Additions: `ShimmerModifier`, `ListRowSkeleton`, `CardSkeleton`, design docs.

**Tech Stack:** SwiftUI, XCTest

---

## Chunk 1: Phase 1 — Foundation

### File Map

| Action | Path |
|--------|------|
| Modify | `TheRecruitingCompass/TheRecruitingCompass/Core/Theme/AppColors.swift` |
| Modify | `TheRecruitingCompass/TheRecruitingCompass/Core/Theme/AppGradients.swift` |
| Modify | `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/BadgeView.swift` |
| Create | `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/BadgeColor.swift` |
| Create | `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/BadgeColorTests.swift` |
| Update | `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Views/InteractionDetailView.swift` (call site) |
| Update | `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolCardView.swift` (call site) |
| Update | `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/FitScoreBadge.swift` (call site) |
| Update | `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Views/SchoolsListViewAccessibilityTests.swift` (test call site) |

---

### Task 1: Restructure `AppColors.swift`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Theme/AppColors.swift`

- [x] **Step 1: Replace `AppColors.swift` with two-layer structure**

  Replace the entire file with:

  ```swift
  import SwiftUI

  extension Color {
    // MARK: - Brand Palette
    // Raw color values. Use Color.brand.* or BadgeColor for semantic contexts.
    enum brand {
      // Blue — primary actions, links, in-progress
      static let blue100 = Color(hex: "dbeafe")
      static let blue500 = Color(hex: "3b82f6")
      static let blue600 = Color(hex: "2563eb")
      static let blue700 = Color(hex: "1d4ed8")
      // Emerald — success, completed, inbound
      static let emerald100 = Color(hex: "d1fae5")
      static let emerald500 = Color(hex: "10b981")
      static let emerald600 = Color(hex: "059669")
      static let emerald700 = Color(hex: "047857")
      // Orange — warning, pending, reach
      static let orange100 = Color(hex: "ffedd5")
      static let orange500 = Color(hex: "f97316")
      static let orange600 = Color(hex: "ea580c")
      static let orange700 = Color(hex: "c2410c")
      // Purple — secondary, outbound, academic
      static let purple100 = Color(hex: "ede9fe")
      static let purple500 = Color(hex: "8b5cf6")
      static let purple600 = Color(hex: "7c3aed")
      static let purple700 = Color(hex: "6d28d9")
      // Red — error, danger, destructive, negative
      static let red100 = Color(hex: "fee2e2")
      static let red500 = Color(hex: "ef4444")
      static let red600 = Color(hex: "dc2626")
      static let red700 = Color(hex: "b91c1c")
      // Slate — neutral, disabled, default
      static let slate100 = Color(hex: "f1f5f9")
      static let slate500 = Color(hex: "64748b")
      static let slate600 = Color(hex: "475569")
      static let slate700 = Color(hex: "334155")
      // Indigo — accent (reserved for future button use)
      static let indigo100 = Color(hex: "e0e7ff")
      static let indigo500 = Color(hex: "6366f1")
      static let indigo600 = Color(hex: "4f46e5")
      static let indigo700 = Color(hex: "4338ca")
    }

    // MARK: - Semantic Aliases
    enum semantic {
      static let actionPrimary = Color.brand.blue600
      static let success = Color.brand.emerald600
      static let warning = Color.brand.orange600
      static let danger = Color.brand.red600
      static let muted = Color.brand.slate500
    }

    // MARK: - Legacy Aliases (bridge for existing callers)
    static let primaryGreen = Color.brand.emerald600
    static let darkEmerald = Color.brand.emerald700
    static let emeraldGradientStart = Color.brand.emerald500
    static let emeraldGradientEnd = Color.brand.emerald600
    static let darkSlate = Color.brand.slate700
    static let secondaryText = Color.brand.slate500
    static let tertiaryText = Color.brand.slate600
    static let nearBlack = Color(hex: "0d0d1a")
    static let accentBlue = Color.brand.blue600
    static let blueGradientStart = Color.brand.blue500
    static let blueGradientEnd = Color.brand.blue700
    static let errorRed = Color.brand.red600
    static let errorBackground = Color.brand.red100
    static let errorBorder = Color(hex: "fecaca")
    static let warningOrange = Color.brand.orange700
    static let warningBackground = Color.brand.orange100
    static let warningBorder = Color(hex: "fed7aa")
    static let strengthOrange = Color.brand.orange500
    static let amberGold = Color(hex: "b45309")
    static let successGreen = Color.brand.emerald600
    static let iconGray = Color.brand.slate500
    static let borderGray = Color.brand.slate100

    // MARK: - Hex Initializer
    init(hex: String) {
      let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
      var hexNumber: UInt64 = 0
      scanner.scanHexInt64(&hexNumber)
      let r = Double((hexNumber & 0xff0000) >> 16) / 255
      let g = Double((hexNumber & 0x00ff00) >> 8) / 255
      let b = Double(hexNumber & 0x0000ff) / 255
      self.init(red: r, green: g, blue: b)
    }
  }
  ```

---

### Task 2: Write failing `BadgeColor` tests

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/BadgeColorTests.swift`

- [x] **Step 1: Create the test file**

  ```swift
  import XCTest
  import SwiftUI
  @testable import TheRecruitingCompass

  final class BadgeColorTests: XCTestCase {

    func test_blue_backgroundColor_usesBrandBlue100() {
      XCTAssertEqual(BadgeColor.blue.backgroundColor, Color.brand.blue100)
    }

    func test_blue_foregroundColor_usesBrandBlue700() {
      XCTAssertEqual(BadgeColor.blue.foregroundColor, Color.brand.blue700)
    }

    func test_emerald_backgroundColor_usesBrandEmerald100() {
      XCTAssertEqual(BadgeColor.emerald.backgroundColor, Color.brand.emerald100)
    }

    func test_red_foregroundColor_usesBrandRed700() {
      XCTAssertEqual(BadgeColor.red.foregroundColor, Color.brand.red700)
    }

    func test_slate_indicatorColor_usesBrandSlate500() {
      XCTAssertEqual(BadgeColor.slate.indicatorColor, Color.brand.slate500)
    }

    func test_allCases_haveNonNilColors() {
      for color in BadgeColor.allCases {
        // Smoke-test: properties return without crashing
        _ = color.backgroundColor
        _ = color.foregroundColor
        _ = color.indicatorColor
      }
    }

    func test_allCasesCount() {
      XCTAssertEqual(BadgeColor.allCases.count, 6)
    }
  }
  ```

- [x] **Step 2: Verify the test file fails to compile** (expected — `BadgeColor` doesn't exist yet)

---

### Task 3: Create `BadgeColor.swift`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/BadgeColor.swift`

- [x] **Step 1: Create the file**

  ```swift
  import SwiftUI

  /// Semantic badge color vocabulary. Matches the web app's BadgeColor type exactly.
  /// - blue: primary actions, in-progress, interaction type
  /// - emerald: success, completed, inbound
  /// - orange: warning, pending, reach
  /// - purple: secondary, outbound
  /// - red: error, danger, destructive, negative
  /// - slate: neutral, disabled, fallback
  enum BadgeColor: CaseIterable {
    case blue, emerald, orange, purple, red, slate

    var backgroundColor: Color {
      switch self {
      case .blue:    return Color.brand.blue100
      case .emerald: return Color.brand.emerald100
      case .orange:  return Color.brand.orange100
      case .purple:  return Color.brand.purple100
      case .red:     return Color.brand.red100
      case .slate:   return Color.brand.slate100
      }
    }

    var foregroundColor: Color {
      switch self {
      case .blue:    return Color.brand.blue700
      case .emerald: return Color.brand.emerald700
      case .orange:  return Color.brand.orange700
      case .purple:  return Color.brand.purple700
      case .red:     return Color.brand.red700
      case .slate:   return Color.brand.slate700
      }
    }

    /// Mid-tone color for dots, circles, and progress indicators.
    var indicatorColor: Color {
      switch self {
      case .blue:    return Color.brand.blue500
      case .emerald: return Color.brand.emerald500
      case .orange:  return Color.brand.orange500
      case .purple:  return Color.brand.purple500
      case .red:     return Color.brand.red500
      case .slate:   return Color.brand.slate500
      }
    }
  }
  ```

- [x] **Step 2: Run BadgeColor tests — expect PASS**

  ```bash
  cd TheRecruitingCompass
  xcodebuild test -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing TheRecruitingCompassTests/BadgeColorTests
  ```

  Expected: all 7 tests pass.

---

### Task 4: Update `BadgeView` and all call sites atomically

`BadgeView` currently takes `color: Color`. Changing it to `BadgeColor` breaks 4 call sites. Update all of them in this task so the build stays green.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/BadgeView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Views/InteractionDetailView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolCardView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/FitScoreBadge.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Views/SchoolsListViewAccessibilityTests.swift`

- [x] **Step 1: Update `BadgeView.swift`**

  Replace the entire file:

  ```swift
  import SwiftUI

  struct BadgeView: View {
    let text: String
    let color: BadgeColor
    let icon: String?
    let accessibilityLabel: String?

    init(text: String, color: BadgeColor, icon: String? = nil, accessibilityLabel: String? = nil) {
      self.text = text
      self.color = color
      self.icon = icon
      self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
      HStack(spacing: 4) {
        if let icon = icon {
          Image(systemName: icon)
            .font(.caption)
            .accessibilityHidden(true)
        }
        Text(text)
      }
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, icon != nil ? 12 : 8)
      .padding(.vertical, 6)
      .background(color.backgroundColor)
      .foregroundStyle(color.foregroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .accessibilityLabel(accessibilityLabel ?? text)
    }
  }

  #Preview {
    VStack(spacing: 12) {
      BadgeView(text: "D1", color: .blue)
      BadgeView(text: "Email", color: .blue, icon: "envelope.fill")
      BadgeView(text: "Interested", color: .slate)
      BadgeView(text: "Fit: 85", color: .emerald)
      BadgeView(text: "Tier A", color: .red, accessibilityLabel: "Priority tier A")
    }
    .padding()
  }
  ```

- [x] **Step 2: Update `InteractionDetailView.swift` badge calls**

  At this point `Interaction.direction.badgeColor` and `Interaction.sentiment?.badgeColor` still return `Color` — that will be fixed in Phase 2. For now, pass a hardcoded `BadgeColor` at the call site:

  Replace the `badgesSection` method in `InteractionDetailView.swift`:

  ```swift
  private func badgesSection(interaction: Interaction) -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        // Type badge — always blue per design system
        BadgeView(
          text: interaction.type.displayName,
          color: .blue,
          icon: interaction.type.iconName,
          accessibilityLabel: "\(interaction.type.displayName) interaction"
        )

        // Direction badge — will be typed in Phase 2, hardcoded for now
        BadgeView(
          text: interaction.direction.displayName,
          color: interaction.direction == .inbound ? .emerald : .purple,
          accessibilityLabel: "\(interaction.direction.displayName) direction"
        )

        // Sentiment badge
        if let sentiment = interaction.sentiment {
          BadgeView(
            text: sentiment.displayName,
            color: sentiment.displayBadgeColor,
            accessibilityLabel: "Sentiment: \(sentiment.displayName)"
          )
        }
      }
    }
    .scrollIndicators(.hidden)
  }
  ```

  > **Note:** `sentiment.displayBadgeColor` does not exist yet. Add a temporary computed property to `Sentiment` in `Interaction.swift` right now, returning `BadgeColor`:

  In `Interaction.swift`, add to `Sentiment` enum (alongside the existing `badgeColor: Color`):

  ```swift
  var displayBadgeColor: BadgeColor {
    switch self {
    case .veryPositive: return .emerald
    case .positive:     return .blue
    case .neutral:      return .slate
    case .negative:     return .red
    }
  }
  ```

  The old `badgeColor: Color` property stays for now and is removed in Phase 2.

- [x] **Step 3: Update `SchoolCardView.swift` badge calls**

  In `badgesSection`, update:

  ```swift
  if let division = school.division, let divisionEnum = Division(rawValue: division) {
    BadgeView(text: divisionEnum.displayName, color: divisionEnum.semanticBadgeColor)
  }

  if let statusEnum = SchoolStatus(rawValue: school.status) {
    BadgeView(text: statusEnum.displayName, color: statusEnum.semanticBadgeColor)
  }

  FitScoreBadge(score: school.fitScore)

  if let size = school.size {
    BadgeView(text: size.displayName, color: .slate)
  }
  ```

  > **Note:** `divisionEnum.semanticBadgeColor` and `statusEnum.semanticBadgeColor` are temporary bridge properties returning `BadgeColor`. Add them as extensions now, to be replaced by the main `badgeColor: BadgeColor` in Phase 2:

  In `Division.swift`, add:
  ```swift
  var semanticBadgeColor: BadgeColor {
    switch self {
    case .d1:   return .blue
    case .d2:   return .emerald
    case .d3:   return .orange
    case .naia: return .purple
    case .juco: return .slate
    }
  }
  ```

  In `SchoolStatus.swift`, add:
  ```swift
  var semanticBadgeColor: BadgeColor {
    switch self {
    case .interested:              return .slate
    case .contacted:               return .blue
    case .campInvite:              return .purple
    case .recruited:               return .emerald
    case .officialVisitInvited:    return .orange
    case .officialVisitScheduled:  return .orange
    case .offerReceived:           return .emerald
    case .committed:               return .emerald
    case .notPursuing:             return .red
    case .unknown:                 return .slate
    }
  }
  ```

- [x] **Step 4: Update `FitScoreBadge.swift`**

  Replace the entire file:

  ```swift
  import SwiftUI

  struct FitScoreBadge: View {
    let score: Double?

    private var displayScore: Int { Int(score ?? 0) }

    private var badgeColor: BadgeColor {
      guard let score else { return .slate }
      if score >= 70 { return .emerald }
      if score >= 50 { return .orange }
      return .red
    }

    var body: some View {
      if score != nil {
        BadgeView(
          text: "Fit: \(displayScore)",
          color: badgeColor,
          accessibilityLabel: "Fit score \(displayScore) out of 100"
        )
      }
    }
  }

  #Preview {
    VStack(spacing: 12) {
      FitScoreBadge(score: 85)
      FitScoreBadge(score: 65)
      FitScoreBadge(score: 45)
      FitScoreBadge(score: nil)
    }
    .padding()
  }
  ```

- [x] **Step 5: Fix `SchoolsListViewAccessibilityTests.swift`**

  Search for any `BadgeView(color:)` call in this file that passes a raw `Color`. Replace with the appropriate `BadgeColor` case. If the test instantiates `BadgeView` directly, update the argument. If it only queries accessibility labels, no change needed.

- [x] **Step 6: Build — expect clean compile**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

  Expected: BUILD SUCCEEDED. Fix any remaining `BadgeView(color: Color)` compile errors before proceeding.

---

### Task 5: Update `AppGradients.swift`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Theme/AppGradients.swift`

- [x] **Step 1: Replace raw color values with brand tokens**

  ```swift
  import SwiftUI

  extension LinearGradient {
    static let primaryBackground = LinearGradient(
      gradient: Gradient(colors: [Color.brand.emerald500, Color.brand.emerald700]),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )

    static let landingBackground = LinearGradient(
      gradient: Gradient(colors: [Color.brand.emerald500, Color.brand.emerald600]),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )

    static let primaryButton = LinearGradient(
      gradient: Gradient(colors: [Color.brand.blue500, Color.brand.blue700]),
      startPoint: .leading,
      endPoint: .trailing
    )
  }
  ```

---

### Task 6: Phase 1 build + test + commit

- [x] **Step 1: Build**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

  Expected: BUILD SUCCEEDED.

- [x] **Step 2: Run unit tests**

  ```bash
  xcodebuild test -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

  Expected: all tests pass.

- [x] **Step 3: Commit**

  ```bash
  git add \
    TheRecruitingCompass/TheRecruitingCompass/Core/Theme/AppColors.swift \
    TheRecruitingCompass/TheRecruitingCompass/Core/Theme/AppGradients.swift \
    TheRecruitingCompass/TheRecruitingCompass/Shared/Components/BadgeColor.swift \
    TheRecruitingCompass/TheRecruitingCompass/Shared/Components/BadgeView.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/FitScoreBadge.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/Division.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/SchoolStatus.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolCardView.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Views/InteractionDetailView.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Models/Interaction.swift \
    TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/BadgeColorTests.swift
  git commit -m "feat: add brand palette + BadgeColor enum, migrate BadgeView to typed colors"
  ```

---

## Chunk 2: Phase 2 — Model + View Call Site Sweep

### File Map

| Action | Path |
|--------|------|
| Modify | `Features/Interactions/Models/Interaction.swift` |
| Modify | `Features/Interactions/Components/InteractionCard.swift` |
| Modify | `Features/Schools/Models/FitScore.swift` |
| Modify | `Features/Schools/Components/FitScoreSection.swift` |
| Modify | `Features/Schools/Models/PriorityTier.swift` |
| Modify | `Features/Schools/Models/SchoolStatus.swift` |
| Modify | `Features/Schools/Models/Division.swift` |
| Modify | `Features/Interactions/Models/InterestLevel.swift` |
| Modify | `Features/Analytics/Models/AnalyticsChartColors.swift` |
| Modify | `Features/Schools/Components/SchoolBadges.swift` |
| Modify | `Features/Dashboard/Components/StatCardSkeleton.swift` |

All paths below are relative to `TheRecruitingCompass/TheRecruitingCompass/`.

---

### Task 7: `Interaction.swift` — finalize typed colors

Remove the temporary bridge properties added in Phase 1 and replace with typed `badgeColor: BadgeColor` as the canonical property.

**Files:**
- Modify: `Features/Interactions/Models/Interaction.swift`
- Modify: `Features/Interactions/Components/InteractionCard.swift`
- Modify: `Features/Interactions/Views/InteractionDetailView.swift`

- [x] **Step 1: Update `InteractionType` in `Interaction.swift`**

  Replace `iconColor: Color` with two properties:

  ```swift
  // Keep iconName: String unchanged

  /// Tint color for SF Symbol rendering (non-badge contexts).
  var tintColor: Color {
    switch self {
    case .email:          return Color.brand.blue600
    case .phoneCall:      return Color.brand.purple600
    case .text:           return Color.brand.emerald600
    case .inPersonVisit:  return Color.brand.orange600
    case .virtualMeeting: return Color.brand.indigo600
    case .camp:           return Color.brand.orange600
    case .showcase:       return Color.brand.purple500
    case .tweet:          return Color.brand.blue500
    case .directMessage:  return Color.brand.purple600
    case .unknown:        return Color.brand.slate500
    }
  }

  /// Badge color — always blue per design system (type label carries semantic meaning).
  var badgeColor: BadgeColor { .blue }
  ```

  Remove the old `iconColor: Color` property entirely.

- [x] **Step 2: Update `Direction` in `Interaction.swift`**

  Replace `badgeColor: Color` with:

  ```swift
  var badgeColor: BadgeColor {
    switch self {
    case .outbound: return .purple
    case .inbound:  return .emerald
    }
  }
  ```

- [x] **Step 3: Update `Sentiment` in `Interaction.swift`**

  Replace `badgeColor: Color` with `badgeColor: BadgeColor`. Remove `displayBadgeColor` (the Phase 1 bridge):

  ```swift
  var badgeColor: BadgeColor {
    switch self {
    case .veryPositive: return .emerald
    case .positive:     return .blue
    case .neutral:      return .slate
    case .negative:     return .red
    }
  }
  ```

- [x] **Step 4: Update `InteractionDetailView.swift` — use typed properties**

  In `badgesSection`, replace the hardcoded direction/sentiment logic with the now-typed properties:

  ```swift
  BadgeView(
    text: interaction.type.displayName,
    color: interaction.type.badgeColor,
    icon: interaction.type.iconName,
    accessibilityLabel: "\(interaction.type.displayName) interaction"
  )

  BadgeView(
    text: interaction.direction.displayName,
    color: interaction.direction.badgeColor,
    accessibilityLabel: "\(interaction.direction.displayName) direction"
  )

  if let sentiment = interaction.sentiment {
    BadgeView(
      text: sentiment.displayName,
      color: sentiment.badgeColor,
      accessibilityLabel: "Sentiment: \(sentiment.displayName)"
    )
  }
  ```

  Also replace any remaining `interaction.type.iconColor` with `interaction.type.tintColor`.

- [x] **Step 5: Update `InteractionCard.swift`**

  Search for references to `.iconColor`, `.badgeColor` (returning `Color`), or `.displayBadgeColor`. Update:
  - `iconColor` → `tintColor`
  - `direction.badgeColor` and `sentiment?.badgeColor` now return `BadgeColor` — if passed to `BadgeView`, they're already correct. If used in a `foregroundStyle()` call, wrap as: `foregroundStyle(direction.badgeColor.foregroundColor)`.

- [x] **Step 6: Build**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

  Expected: BUILD SUCCEEDED.

- [x] **Step 7: Commit**

  ```bash
  git add TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/
  git commit -m "refactor: migrate Interaction color properties to BadgeColor"
  ```

---

### Task 8: `FitScore.swift` + `FitScoreSection.swift`

**Files:**
- Modify: `Features/Schools/Models/FitScore.swift`
- Modify: `Features/Schools/Components/FitScoreSection.swift`

- [x] **Step 1: Update `FitTier` in `FitScore.swift`**

  Remove `badgeColors: (background: Color, text: Color)`. Replace with `badgeColor: BadgeColor`:

  ```swift
  var badgeColor: BadgeColor {
    switch self {
    case .reach:    return .orange
    case .match:    return .emerald
    case .safety:   return .emerald
    case .unlikely: return .red
    }
  }
  ```

- [x] **Step 2: Update `FitScoreSection.swift`**

  **Tier badge section** — replace `.badgeColors.background/.text` with typed properties:

  ```swift
  Circle()
    .fill(fitScore.tier.badgeColor.indicatorColor)
    .frame(width: 8, height: 8)
    .accessibilityHidden(true)

  Text(fitScore.tier.displayName)
    .font(.subheadline)
    .fontWeight(.semibold)
    .foregroundStyle(fitScore.tier.badgeColor.foregroundColor)
  ```
  ```swift
  .background(fitScore.tier.badgeColor.backgroundColor)
  ```

  **Numeric score color** — replace `fitScoreColor()` with brand tokens:

  ```swift
  private func fitScoreColor(_ score: Double) -> Color {
    if score >= 70 { return Color.brand.emerald600 }
    if score >= 50 { return Color.brand.orange600 }
    return Color.brand.red600
  }
  ```

  **Breakdown dimension colors** — update `BreakdownRow` color arguments:

  ```swift
  BreakdownRow(label: "Athletic Fit",    score: athletic,    color: Color.brand.blue500)
  BreakdownRow(label: "Academic Fit",    score: academic,    color: Color.brand.purple500)
  BreakdownRow(label: "Opportunity Fit", score: opportunity, color: Color.brand.emerald500)
  BreakdownRow(label: "Personal Fit",    score: personal,    color: Color.brand.orange500)
  ```

  **Reduced motion for expand animation** — add `@Environment` and conditionally animate:

  ```swift
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // In the expand button action:
  Button {
    if reduceMotion {
      isExpanded.toggle()
    } else {
      withAnimation { isExpanded.toggle() }
    }
  } label: { ... }
  ```

  Also update the `.transition`:
  ```swift
  .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
  ```

- [x] **Step 3: Build**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

  Expected: BUILD SUCCEEDED.

- [x] **Step 4: Commit**

  ```bash
  git add \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/FitScore.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/FitScoreSection.swift
  git commit -m "refactor: migrate FitTier to BadgeColor, add reduced motion to FitScoreSection"
  ```

---

### Task 9: `PriorityTier.swift` — fix critical mismatch

**Files:**
- Modify: `Features/Schools/Models/PriorityTier.swift`
- Modify: `Features/Schools/Components/SchoolBadges.swift` (`PriorityTierBadge`)

**Current (wrong):** A=gold, B=silver, C=bronze.
**Correct (web-aligned):** A=red (urgency/importance), B=orange (strong interest), C=slate (fallback).

- [x] **Step 1: Update `PriorityTier.swift`**

  ```swift
  var badgeColor: BadgeColor {
    switch self {
    case .a: return .red
    case .b: return .orange
    case .c: return .slate
    }
  }
  ```

  Remove the old `badgeColor: Color` property.

- [x] **Step 2: Update `PriorityTierBadge` in `SchoolBadges.swift`**

  ```swift
  struct PriorityTierBadge: View {
    let tier: PriorityTier

    var body: some View {
      Text("Tier \(tier.displayName)")
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tier.badgeColor.backgroundColor)
        .foregroundStyle(tier.badgeColor.foregroundColor)
        .clipShape(Capsule())
        .accessibilityLabel("Priority Tier \(tier.displayName)")
    }
  }
  ```

- [x] **Step 3: Build + commit**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  git add \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/PriorityTier.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolBadges.swift
  git commit -m "fix: align PriorityTier colors with web (A=red, B=orange, C=slate)"
  ```

---

### Task 10: `SchoolStatus.swift` — finalize typed colors

**Files:**
- Modify: `Features/Schools/Models/SchoolStatus.swift`
- Modify: `Features/Schools/Components/SchoolBadges.swift` (`StatusBadge`)
- Modify: `Features/Schools/Components/SchoolCardView.swift` (remove `semanticBadgeColor` bridge)

- [x] **Step 1: Update `SchoolStatus.swift`**

  Replace `badgeColor: Color` and `badgeColors: (background: Color, text: Color)` with a single `badgeColor: BadgeColor`. The `semanticBadgeColor` added in Phase 1 becomes the canonical `badgeColor`:

  ```swift
  var badgeColor: BadgeColor {
    switch self {
    case .interested:             return .slate
    case .contacted:              return .blue
    case .campInvite:             return .purple
    case .recruited:              return .emerald
    case .officialVisitInvited:   return .orange
    case .officialVisitScheduled: return .orange
    case .offerReceived:          return .emerald
    case .committed:              return .emerald
    case .notPursuing:            return .red
    case .unknown:                return .slate
    }
  }
  ```

  Remove `semanticBadgeColor`, the old `badgeColor: Color`, and `badgeColors`.

- [x] **Step 2: Update `StatusBadge` in `SchoolBadges.swift`**

  ```swift
  struct StatusBadge: View {
    let status: SchoolStatus

    var body: some View {
      Text(status.displayName)
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.badgeColor.backgroundColor)
        .foregroundStyle(status.badgeColor.foregroundColor)
        .clipShape(Capsule())
        .accessibilityLabel("Status: \(status.displayName)")
    }
  }
  ```

- [x] **Step 3: Update `SchoolCardView.swift`**

  Remove `semanticBadgeColor` bridge; use `badgeColor` directly:

  ```swift
  BadgeView(text: statusEnum.displayName, color: statusEnum.badgeColor)
  ```

- [x] **Step 4: Build + commit**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  git add \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/SchoolStatus.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolBadges.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolCardView.swift
  git commit -m "refactor: migrate SchoolStatus to BadgeColor, remove legacy color tuples"
  ```

---

### Task 11: `Division.swift` — finalize typed colors

**Files:**
- Modify: `Features/Schools/Models/Division.swift`
- Modify: `Features/Schools/Components/SchoolBadges.swift` (`DivisionBadge`)
- Modify: `Features/Schools/Components/SchoolCardView.swift` (remove `semanticBadgeColor` bridge)

- [x] **Step 1: Update `Division.swift`**

  Replace `badgeColor: Color` and remove `semanticBadgeColor`:

  ```swift
  var badgeColor: BadgeColor {
    switch self {
    case .d1:   return .blue
    case .d2:   return .emerald
    case .d3:   return .orange
    case .naia: return .purple
    case .juco: return .slate
    }
  }
  ```

- [x] **Step 2: Consolidate `DivisionBadge` in `SchoolBadges.swift`**

  `DivisionBadge` currently takes a `String` and has its own switch. Consolidate:

  ```swift
  struct DivisionBadge: View {
    let division: String

    private var badgeColor: BadgeColor {
      Division(rawValue: division.uppercased())?.badgeColor ?? .slate
    }

    var body: some View {
      Text(division.uppercased())
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(badgeColor.backgroundColor)
        .foregroundStyle(badgeColor.foregroundColor)
        .clipShape(Capsule())
        .accessibilityLabel("Division: \(division)")
    }
  }
  ```

- [x] **Step 3: Update `SchoolCardView.swift`**

  Remove `semanticBadgeColor` bridge; use `badgeColor` directly:

  ```swift
  BadgeView(text: divisionEnum.displayName, color: divisionEnum.badgeColor)
  ```

- [x] **Step 4: Build + commit**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  git add \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/Division.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolBadges.swift \
    TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolCardView.swift
  git commit -m "refactor: migrate Division to BadgeColor, consolidate DivisionBadge"
  ```

---

### Task 12: `InterestLevel.swift` + callers

**Files:**
- Modify: `Features/Interactions/Models/InterestLevel.swift`

- [x] **Step 1: Update `InterestLevel.swift`**

  Replace `color: Color` with `badgeColor: BadgeColor`:

  ```swift
  var badgeColor: BadgeColor {
    switch self {
    case .high:   return .emerald
    case .medium: return .orange
    case .low:    return .slate
    case .notSet: return .slate
    }
  }
  ```

- [x] **Step 2: Fix callers**

  Search the codebase for `.interestLevel?.color` or `.color` on `InterestLevel` values:

  ```bash
  grep -r "interestLevel" TheRecruitingCompass/TheRecruitingCompass --include="*.swift" -l
  ```

  For each caller: if passing to `BadgeView`, change to `.badgeColor`. If using in `foregroundStyle()`, change to `.badgeColor.foregroundColor`.

- [x] **Step 3: Build + commit**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  git add TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/
  git commit -m "refactor: migrate InterestLevel.color to BadgeColor"
  ```

---

### Task 13: `AnalyticsChartColors.swift`

**Files:**
- Modify: `Features/Analytics/Models/AnalyticsChartColors.swift`

The existing tests only check counts and identity (not specific hex values), so they will still pass after this change.

- [x] **Step 1: Replace raw hex strings with brand tokens**

  ```swift
  import SwiftUI

  enum AnalyticsChartColors {
    static let primary   = Color.brand.blue500
    static let secondary = Color.brand.emerald500
    static let tertiary  = Color.brand.orange500
    static let quaternary = Color.brand.red500
    static let purple    = Color.brand.purple500
    static let pink      = Color(hex: "ec4899")  // pink has no brand token; keep raw hex

    static let palette: [Color] = [
      primary, secondary, tertiary, quaternary, purple, pink
    ]

    static func color(at index: Int) -> Color {
      palette[index % palette.count]
    }

    static let funnelPalette: [Color] = [
      primary, secondary, tertiary, quaternary
    ]

    static let sentimentColors: [String: Color] = [
      "Positive":      secondary,
      "Very Positive": Color.brand.emerald600,
      "Neutral":       Color.brand.slate500,
      "Negative":      quaternary
    ]
  }
  ```

- [x] **Step 2: Run AnalyticsChartColors tests**

  ```bash
  cd TheRecruitingCompass
  xcodebuild test -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing TheRecruitingCompassTests/AnalyticsChartColorsTests
  ```

  Expected: all 9 tests pass (tests check identity/count, not hex values).

- [x] **Step 3: Commit**

  ```bash
  git add TheRecruitingCompass/TheRecruitingCompass/Features/Analytics/Models/AnalyticsChartColors.swift
  git commit -m "refactor: migrate AnalyticsChartColors to brand palette tokens"
  ```

---

### Task 14: `StatCardSkeleton.swift` — add reduced motion

**Files:**
- Modify: `Features/Dashboard/Components/StatCardSkeleton.swift`

- [x] **Step 1: Add `@Environment(\.accessibilityReduceMotion)` and conditional animation**

  ```swift
  import SwiftUI

  struct StatCardSkeleton: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        Circle()
          .fill(Color.brand.slate100)
          .frame(width: 32, height: 32)

        VStack(alignment: .leading, spacing: 8) {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.brand.slate100)
            .frame(height: 32)

          RoundedRectangle(cornerRadius: 4)
            .fill(Color.brand.slate100)
            .frame(width: 100, height: 16)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, minHeight: 120)
      .background(Color.brand.slate100.opacity(0.5))
      .clipShape(.rect(cornerRadius: 12))
      .opacity(isAnimating ? 0.5 : 1.0)
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
        value: isAnimating
      )
      .onAppear { if !reduceMotion { isAnimating = true } }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Loading statistics")
      .accessibilityAddTraits(.updatesFrequently)
    }
  }

  #Preview {
    StatCardSkeleton()
      .padding()
  }
  ```

- [x] **Step 2: Build + commit**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/StatCardSkeleton.swift
  git commit -m "fix: add reduced motion support to StatCardSkeleton, use brand slate tokens"
  ```

---

### Task 15: Phase 2 full test run

- [x] **Step 1: Run full test suite**

  ```bash
  cd TheRecruitingCompass
  xcodebuild test -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

  Expected: all tests pass. Fix any failures before proceeding.

---

## Chunk 3: Phase 3 — Additions

### File Map

| Action | Path |
|--------|------|
| Create | `Shared/Components/ShimmerModifier.swift` |
| Create | `Shared/Components/ListRowSkeleton.swift` |
| Create | `Shared/Components/CardSkeleton.swift` |
| Create | `docs/design/tokens.md` |
| Create | `docs/design/colors.md` |
| Create | `docs/design/states.md` |
| Create | `docs/design/components.md` |

All Swift file paths below are relative to `TheRecruitingCompass/TheRecruitingCompass/`.

---

### Task 16: `ShimmerModifier.swift`

**Files:**
- Create: `Shared/Components/ShimmerModifier.swift`

- [x] **Step 1: Create the file**

  ```swift
  import SwiftUI

  /// Applies a shimmer animation to any view for skeleton loading states.
  /// Automatically disables animation when accessibilityReduceMotion is enabled.
  struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
      content
        .opacity(reduceMotion ? 0.6 : (isAnimating ? 0.4 : 0.8))
        .animation(
          reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
          value: isAnimating
        )
        .onAppear { if !reduceMotion { isAnimating = true } }
    }
  }

  extension View {
    func shimmer() -> some View {
      modifier(ShimmerModifier())
    }
  }
  ```

---

### Task 17: `ListRowSkeleton.swift`

**Files:**
- Create: `Shared/Components/ListRowSkeleton.swift`

- [x] **Step 1: Create the file**

  ```swift
  import SwiftUI

  /// Skeleton placeholder for a single list row while data is loading.
  /// Usage: ForEach(0..<5, id: \.self) { _ in ListRowSkeleton() }
  struct ListRowSkeleton: View {
    var body: some View {
      HStack(spacing: 12) {
        Circle()
          .fill(Color.brand.slate100)
          .frame(width: 40, height: 40)

        VStack(alignment: .leading, spacing: 6) {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.brand.slate100)
            .frame(height: 14)

          RoundedRectangle(cornerRadius: 4)
            .fill(Color.brand.slate100)
            .frame(width: 160, height: 12)
        }

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .shimmer()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Loading")
      .accessibilityAddTraits(.updatesFrequently)
    }
  }

  #Preview {
    VStack(spacing: 0) {
      ForEach(0..<5, id: \.self) { _ in
        ListRowSkeleton()
        Divider()
      }
    }
  }
  ```

---

### Task 18: `CardSkeleton.swift`

**Files:**
- Create: `Shared/Components/CardSkeleton.swift`

- [x] **Step 1: Create the file**

  ```swift
  import SwiftUI

  /// Skeleton placeholder for a card while data is loading.
  /// Usage: CardSkeleton() or LazyVGrid { ForEach(0..<4) { _ in CardSkeleton() } }
  struct CardSkeleton: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.brand.slate100)
          .frame(height: 16)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color.brand.slate100)
          .frame(height: 12)
          .frame(maxWidth: .infinity)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color.brand.slate100)
          .frame(width: 100, height: 12)

        Spacer()

        HStack(spacing: 8) {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.brand.slate100)
            .frame(width: 60, height: 22)
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.brand.slate100)
            .frame(width: 50, height: 22)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, minHeight: 140)
      .background(Color.brand.slate100.opacity(0.4))
      .clipShape(.rect(cornerRadius: 12))
      .shimmer()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Loading")
      .accessibilityAddTraits(.updatesFrequently)
    }
  }

  #Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      ForEach(0..<4, id: \.self) { _ in CardSkeleton() }
    }
    .padding()
  }
  ```

- [x] **Step 2: Build all skeleton components**

  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

  Expected: BUILD SUCCEEDED.

- [x] **Step 3: Commit skeleton components**

  ```bash
  git add \
    TheRecruitingCompass/TheRecruitingCompass/Shared/Components/ShimmerModifier.swift \
    TheRecruitingCompass/TheRecruitingCompass/Shared/Components/ListRowSkeleton.swift \
    TheRecruitingCompass/TheRecruitingCompass/Shared/Components/CardSkeleton.swift
  git commit -m "feat: add ShimmerModifier, ListRowSkeleton, CardSkeleton with reduced motion support"
  ```

---

### Task 19: Design docs

**Files:**
- Create: `docs/design/tokens.md`
- Create: `docs/design/colors.md`
- Create: `docs/design/states.md`
- Create: `docs/design/components.md`

- [x] **Step 1: Create `docs/design/tokens.md`**

  ```markdown
  # Design Tokens — iOS

  Source: `TheRecruitingCompass/Core/Theme/AppColors.swift`

  ## Brand Palette

  Raw color values. Access via `Color.brand.*`. Use `BadgeColor` for semantic badge contexts.

  | Token | Hex | Role |
  |-------|-----|------|
  | `Color.brand.blue100` | #dbeafe | Blue light background |
  | `Color.brand.blue500` | #3b82f6 | Blue mid (charts, indicators) |
  | `Color.brand.blue600` | #2563eb | Blue primary (actions) |
  | `Color.brand.blue700` | #1d4ed8 | Blue dark (foreground) |
  | `Color.brand.emerald100` | #d1fae5 | Emerald light |
  | `Color.brand.emerald500` | #10b981 | Emerald mid |
  | `Color.brand.emerald600` | #059669 | Emerald primary |
  | `Color.brand.emerald700` | #047857 | Emerald dark |
  | `Color.brand.orange100` | #ffedd5 | Orange light |
  | `Color.brand.orange500` | #f97316 | Orange mid |
  | `Color.brand.orange600` | #ea580c | Orange primary |
  | `Color.brand.orange700` | #c2410c | Orange dark |
  | `Color.brand.purple100` | #ede9fe | Purple light |
  | `Color.brand.purple500` | #8b5cf6 | Purple mid |
  | `Color.brand.purple600` | #7c3aed | Purple primary |
  | `Color.brand.purple700` | #6d28d9 | Purple dark |
  | `Color.brand.red100` | #fee2e2 | Red light |
  | `Color.brand.red500` | #ef4444 | Red mid |
  | `Color.brand.red600` | #dc2626 | Red primary |
  | `Color.brand.red700` | #b91c1c | Red dark |
  | `Color.brand.slate100` | #f1f5f9 | Slate light |
  | `Color.brand.slate500` | #64748b | Slate mid |
  | `Color.brand.slate600` | #475569 | Slate primary |
  | `Color.brand.slate700` | #334155 | Slate dark |
  | `Color.brand.indigo100` | #e0e7ff | Indigo light (accent) |
  | `Color.brand.indigo500` | #6366f1 | Indigo mid |
  | `Color.brand.indigo600` | #4f46e5 | Indigo primary |
  | `Color.brand.indigo700` | #4338ca | Indigo dark |

  ## Semantic Aliases

  | Token | Maps to | Use for |
  |-------|---------|---------|
  | `Color.semantic.actionPrimary` | `brand.blue600` | Primary interactive elements |
  | `Color.semantic.success` | `brand.emerald600` | Success states |
  | `Color.semantic.warning` | `brand.orange600` | Warning states |
  | `Color.semantic.danger` | `brand.red600` | Destructive/error states |
  | `Color.semantic.muted` | `brand.slate500` | Secondary text, disabled |

  ## Rules

  - Never write raw hex (`Color(hex: "3b82f6")`) in views — use `Color.brand.*`
  - Never write system colors (`.green`, `.blue`, `.red`) for semantic status — use `BadgeColor` or `Color.brand.*`
  - System colors (`.primary`, `.secondary`, `.tertiarySystemBackground`) are fine for structural/layout use
  ```

- [x] **Step 2: Create `docs/design/colors.md`**

  ```markdown
  # Color Roles — iOS

  Source: `BadgeColor.swift`. Use `BadgeColor` for all domain status badges.

  ## Vocabulary

  ```swift
  enum BadgeColor { case blue, emerald, orange, purple, red, slate }
  ```

  ## Blue — Action / In-Progress / Interaction Type

  **Signal:** Active, interactive, primary call to action, in-progress.

  **Use for:**
  - Primary buttons, CTA links
  - `InteractionType.badgeColor` (all types always blue)
  - In-progress school status (`contacted`)
  - Active filter states

  **Brand tokens:** `Color.brand.blue100/.blue500/.blue600/.blue700`

  ---

  ## Emerald — Success / Positive / Inbound / Complete

  **Signal:** Done, good outcome, received communication, strong fit.

  **Use for:**
  - `Sentiment.veryPositive`
  - `Direction.inbound`
  - `SchoolStatus.recruited`, `.offerReceived`, `.committed`
  - `FitTier.match`, `.safety`
  - Fit score ≥ 70
  - `InterestLevel.high`

  **Brand tokens:** `Color.brand.emerald100/.emerald500/.emerald600/.emerald700`

  ---

  ## Orange — Warning / Pending / Reach

  **Signal:** Needs attention, not yet resolved, below target but achievable.

  **Use for:**
  - `SchoolStatus.officialVisitInvited`, `.officialVisitScheduled`
  - `FitTier.reach`
  - Fit score ≥ 50 and < 70
  - `PriorityTier.b` (Strong Interest)
  - `InterestLevel.medium`

  **Brand tokens:** `Color.brand.orange100/.orange500/.orange600/.orange700`

  ---

  ## Purple — Secondary / Outbound / Academic

  **Signal:** Athlete-initiated communication, secondary emphasis.

  **Use for:**
  - `Direction.outbound`
  - `SchoolStatus.campInvite`
  - `Division.naia`

  **Brand tokens:** `Color.brand.purple100/.purple500/.purple600/.purple700`

  ---

  ## Red — Error / Danger / Destructive / Negative

  **Signal:** Bad outcome, delete/remove action, negative sentiment.

  **Use for:**
  - Destructive action buttons ("Delete")
  - `Sentiment.negative`
  - `FitTier.unlikely`
  - Fit score < 50
  - `SchoolStatus.notPursuing`
  - `PriorityTier.a` (Top Choice — red signals urgency, not danger; label clarifies)

  **Brand tokens:** `Color.brand.red100/.red500/.red600/.red700`

  ---

  ## Slate — Neutral / Unknown / Disabled / Default

  **Signal:** No state, not started, unknown, fallback.

  **Use for:**
  - `SchoolStatus.interested`, `.unknown`
  - `Sentiment.neutral`
  - `Division.juco`
  - `PriorityTier.c` (Fallback)
  - `InterestLevel.low`, `.notSet`
  - Size badge (always slate)
  - Disabled / inactive UI elements

  **Brand tokens:** `Color.brand.slate100/.slate500/.slate600/.slate700`

  ---

  ## Quick Reference

  | Color | BadgeColor case | Primary iOS domain use |
  |-------|----------------|----------------------|
  | Blue | `.blue` | Actions, in-progress, interaction type |
  | Emerald | `.emerald` | Success, completed, inbound, high interest |
  | Orange | `.orange` | Warning, pending, reach, medium interest |
  | Purple | `.purple` | Outbound, camp invite |
  | Red | `.red` | Error, danger, negative, top priority |
  | Slate | `.slate` | Neutral, disabled, fallback |
  ```

- [x] **Step 3: Create `docs/design/states.md`**

  ```markdown
  # Domain State → Visual Treatment — iOS

  Canonical reference for how each domain state maps to `BadgeColor`. When building UI that displays state, check here first.

  ---

  ## Fit Score — Tier

  Source: `FitScore.swift (FitTier.badgeColor)`. Rendered via `BadgeColor.backgroundColor/foregroundColor`.

  | Tier | BadgeColor | Meaning |
  |------|-----------|---------|
  | `match` | `.emerald` | Profile aligns well |
  | `safety` | `.emerald` | Strong chance of acceptance |
  | `reach` | `.orange` | Possible fit, needs development |
  | `unlikely` | `.red` | Not a strong fit currently |

  ---

  ## Fit Score — Numeric

  Source: `FitScoreSection.fitScoreColor()`. Applied as foreground color on the score number.

  | Score range | Token | Color |
  |------------|-------|-------|
  | ≥ 70 | `Color.brand.emerald600` | Good |
  | ≥ 50 and < 70 | `Color.brand.orange600` | Caution |
  | < 50 | `Color.brand.red600` | Poor |

  ---

  ## Fit Score — Breakdown Dimensions

  Source: `FitScoreSection.swift`. Progress bar fill colors.

  | Dimension | Token | Max points |
  |-----------|-------|-----------|
  | Athletic Fit | `Color.brand.blue500` | /40 |
  | Academic Fit | `Color.brand.purple500` | /25 |
  | Opportunity Fit | `Color.brand.emerald500` | /20 |
  | Personal Fit | `Color.brand.orange500` | /15 |

  ---

  ## School — Priority Tier

  Source: `PriorityTier.badgeColor`. Note: Tier A uses `.red` to signal urgency/importance, not danger.

  | Tier | BadgeColor | Label |
  |------|-----------|-------|
  | `a` | `.red` | Top Choice |
  | `b` | `.orange` | Strong Interest |
  | `c` | `.slate` | Fallback |

  ---

  ## School — Status

  Source: `SchoolStatus.badgeColor`.

  | Status | BadgeColor |
  |--------|-----------|
  | `interested` | `.slate` |
  | `contacted` | `.blue` |
  | `campInvite` | `.purple` |
  | `recruited` | `.emerald` |
  | `officialVisitInvited` | `.orange` |
  | `officialVisitScheduled` | `.orange` |
  | `offerReceived` | `.emerald` |
  | `committed` | `.emerald` |
  | `notPursuing` | `.red` |
  | `unknown` | `.slate` |

  ---

  ## School — Division

  Source: `Division.badgeColor`.

  | Division | BadgeColor |
  |----------|-----------|
  | `D1` | `.blue` |
  | `D2` | `.emerald` |
  | `D3` | `.orange` |
  | `NAIA` | `.purple` |
  | `JUCO` | `.slate` |

  ---

  ## Interaction — Sentiment

  Source: `Sentiment.badgeColor` in `Interaction.swift`.

  | Sentiment | BadgeColor |
  |-----------|-----------|
  | `veryPositive` | `.emerald` |
  | `positive` | `.blue` |
  | `neutral` | `.slate` |
  | `negative` | `.red` |

  ---

  ## Interaction — Direction

  Source: `Direction.badgeColor` in `Interaction.swift`.

  | Direction | BadgeColor |
  |-----------|-----------|
  | `inbound` | `.emerald` |
  | `outbound` | `.purple` |

  ---

  ## Interaction — Type

  Source: `InteractionType.badgeColor` in `Interaction.swift`.

  Always `.blue`. The type label carries semantic meaning; badge color is structural only.

  ---

  ## Coach Interest Level

  Source: `InterestLevel.badgeColor` in `InterestLevel.swift`.

  | Level | BadgeColor |
  |-------|-----------|
  | `high` | `.emerald` |
  | `medium` | `.orange` |
  | `low` | `.slate` |
  | `notSet` | `.slate` |
  ```

- [x] **Step 4: Create `docs/design/components.md`**

  ```markdown
  # Components Guide — iOS

  ---

  ## BadgeView

  **File:** `TheRecruitingCompass/Shared/Components/BadgeView.swift`

  ```swift
  BadgeView(text: "Committed", color: .emerald)
  BadgeView(text: "Email", color: .blue, icon: "envelope.fill")
  BadgeView(text: "Top Choice", color: .red, accessibilityLabel: "Priority Tier A")
  ```

  **Parameters:**

  | Param | Type | Required | Notes |
  |-------|------|----------|-------|
  | `text` | `String` | ✓ | Badge label |
  | `color` | `BadgeColor` | ✓ | Must be from `BadgeColor` enum — no raw `Color` |
  | `icon` | `String?` | — | SF Symbol name; adjusts horizontal padding |
  | `accessibilityLabel` | `String?` | — | Defaults to `text` if nil |

  **Rule:** Never pass a raw `Color` to `BadgeView`. Always use `BadgeColor`.

  ---

  ## BadgeColor

  **File:** `TheRecruitingCompass/Shared/Components/BadgeColor.swift`

  ```swift
  BadgeColor.blue.backgroundColor   // Color.brand.blue100
  BadgeColor.blue.foregroundColor   // Color.brand.blue700
  BadgeColor.blue.indicatorColor    // Color.brand.blue500 (for dots, circles)
  ```

  Use `.backgroundColor` and `.foregroundColor` when building custom badge-style views that don't use `BadgeView`. Use `.indicatorColor` for status dots, progress circles, and chart elements.

  ---

  ## LoadingStateView

  **File:** `TheRecruitingCompass/Shared/Components/LoadingStateView.swift`

  ```swift
  LoadingStateView(message: "Loading schools...")
  LoadingStateView()  // defaults to "Loading..."
  ```

  Use for full-screen or centered loading states where the content shape is unknown.

  ---

  ## ListRowSkeleton

  **File:** `TheRecruitingCompass/Shared/Components/ListRowSkeleton.swift`

  ```swift
  // While isLoading:
  ForEach(0..<5, id: \.self) { _ in
    ListRowSkeleton()
    Divider()
  }
  ```

  Use in list views (Schools, Coaches, Interactions) while data is fetching. Shows 5 rows to fill typical viewport. Automatically disables animation when `accessibilityReduceMotion` is enabled.

  ---

  ## CardSkeleton

  **File:** `TheRecruitingCompass/Shared/Components/CardSkeleton.swift`

  ```swift
  // While isLoading:
  LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
    ForEach(0..<4, id: \.self) { _ in CardSkeleton() }
  }
  ```

  Use in grid card layouts (dashboard stat cards, school cards) while data is fetching. Automatically disables animation when `accessibilityReduceMotion` is enabled.

  ---

  ## StatCardSkeleton

  **File:** `TheRecruitingCompass/Features/Dashboard/Components/StatCardSkeleton.swift`

  ```swift
  StatCardSkeleton()
  ```

  Dashboard-specific skeleton for stat cards. Prefer `CardSkeleton` for new screens.

  ---

  ## ShimmerModifier

  **File:** `TheRecruitingCompass/Shared/Components/ShimmerModifier.swift`

  ```swift
  RoundedRectangle(cornerRadius: 4)
    .fill(Color.brand.slate100)
    .frame(height: 16)
    .shimmer()
  ```

  Low-level modifier for building custom skeleton shapes. Prefer `ListRowSkeleton` or `CardSkeleton` when the layout matches. Use `.shimmer()` only for one-off skeleton shapes.
  ```

- [x] **Step 5: Commit design docs**

  ```bash
  git add docs/design/
  git commit -m "docs: add iOS design system reference (tokens, colors, states, components)"
  ```

---

### Task 20: Final verification

- [x] **Step 1: Full build + test**

  ```bash
  cd TheRecruitingCompass
  xcodebuild test -scheme TheRecruitingCompass \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

  Expected: BUILD SUCCEEDED, all tests pass.

- [x] **Step 2: Visual spot-check** (manual)

  Open the app in Simulator and verify:
  - Schools list: Division badges use correct colors (D1=blue, D2=emerald, etc.)
  - School card: Priority Tier A badge is now red (not gold)
  - Interaction detail: sentiment/direction badges use correct colors
  - Fit score section: tier badge renders with correct emerald/orange/red
  - Dashboard: stat card skeleton animates (or shows static if Accessibility → Reduce Motion is on)
