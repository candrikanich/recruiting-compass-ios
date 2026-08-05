# Phase 6a — Localization catalog + accessibility-label migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Localizable.xcstrings` String Catalog to the app target and make every `accessibilityLabel` call site catalog-backed, staying English-only.

**Architecture:** The build already runs `-emit-localized-strings`, so Xcode auto-extracts literal-string `LocalizedStringKey` arguments into the catalog with zero code change once it exists. The only code changes needed are for the ~149 `accessibilityLabel` sites whose argument is not a plain string literal (interpolated strings, ternaries, or references to computed properties/functions that build a label) — those get rewritten to route through `String(localized:)` so the *interpolation template*, not the runtime value, becomes the catalog key.

**Tech Stack:** Swift 5, SwiftUI, Xcode String Catalogs (`.xcstrings`), existing `xcodebuild` build/test commands.

## Global Constraints

- Repo root is not the Xcode project — all source paths are `TheRecruitingCompass/TheRecruitingCompass/...` (double-nested).
- New `.swift`/resource files are auto-included via `PBXFileSystemSynchronizedRootGroup` — never edit `.xcodeproj` manually.
- Build: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
- Test: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests`
- Known flake: `RBSRequestErrorDomain Code=5` sim-launch crash mid-suite. If a test run stalls repeatedly at the same point, `xcrun simctl shutdown all && killall -9 CoreSimulatorService`, retry once; if it recurs identically, a machine restart clears it — don't burn more than 2 in-place retries.
- Existing accessibility unit tests read labels via direct computed-property access (not `UIHostingController` tree-walk) and assert on the string *value* — `String(localized:)` output must match the original literal exactly in the base `en` locale, or those tests fail.
- Commit after every task (feature batch) — small, reviewable, bisectable diffs.
- Out of scope: `Text(...)` call sites (645 of them — separate future plan), shipping a second language, non-default catalog keys.

---

### Task 1: Add the String Catalog and verify literal auto-extraction

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings`

**Interfaces:**
- Produces: a target-member `.xcstrings` catalog file that all later tasks rely on existing (no code depends on its Swift API — it's a build-time resource).

- [ ] **Step 1: Create the catalog file**

Create `TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings` with the minimal valid empty-catalog JSON:

```json
{
  "sourceLanguage" : "en",
  "strings" : {},
  "version" : "1.0"
}
```

- [ ] **Step 2: Clean build to trigger extraction**

Run: `cd TheRecruitingCompass && xcodebuild clean build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`

Expected: build succeeds with no new errors (same warnings as before are fine).

- [ ] **Step 3: Verify literal strings were auto-extracted**

Run: `grep -c '"extractionState"' TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings`

Expected: a large number (500+), confirming Xcode populated the catalog from existing `LocalizedStringKey` literals (both `Text("...")` and `accessibilityLabel("...")` call sites) without any other code change.

Then spot-check one known literal exists, e.g.:

Run: `grep -q '"Sign in to account"' TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings && echo FOUND`

Expected: `FOUND` (this string is the Login submit button label, confirmed to exist in `LoginView.swift` per project memory).

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings
git commit -m "feat: add Localizable.xcstrings String Catalog

Enables auto-extraction of literal-string accessibilityLabel/Text
call sites into the catalog at build time (SWIFT_EMIT_LOC_STRINGS
already on). No source changes needed for literal sites."
```

---

### Task 2: Verify ternary-of-literals extraction behavior

**Files:**
- Modify: none yet — this is a verification-only task that decides how Task 3 handles ternary sites.
- Reference: `TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Views/SettingsView.swift:57`

**Interfaces:**
- Consumes: the catalog from Task 1.
- Produces: a documented decision (recorded in this task's commit message) that Task 3+ follow: either "ternaries need no change" or "ternaries need the same `String(localized:)` rewrite as interpolated sites."

- [ ] **Step 1: Inspect the catalog for a known ternary site**

`SettingsView.swift:57` has:
```swift
.accessibilityLabel(showCodeCopied ? "Copied to clipboard" : "Copy family code")
```

Run: `grep -q '"Copied to clipboard"' TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings && echo FOUND_A; grep -q '"Copy family code"' TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings && echo FOUND_B`

- [ ] **Step 2: Record the decision**

If both `FOUND_A` and `FOUND_B` printed: ternaries-of-literals auto-extract correctly (Swift types the ternary as `LocalizedStringKey` from the call-site context). Treat all "ternary of two string literals" sites as **zero-code-change**, same as plain literals, in every later task.

If either is missing: ternary sites need the same `String(localized:)` rewrite as Step 2 of Task 3 (wrap the whole ternary expression: `String(localized: showCodeCopied ? "Copied to clipboard" : "Copy family code")`). Apply that pattern to every ternary site in later tasks instead of leaving them untouched.

- [ ] **Step 3: Commit the decision as a doc note**

Append one line to `docs/superpowers/specs/2026-08-05-localization-a11y-labels-design.md` under "Risks / open questions", replacing the "unconfirmed" wording with the confirmed outcome, then:

```bash
git add docs/superpowers/specs/2026-08-05-localization-a11y-labels-design.md
git commit -m "docs: confirm ternary-of-literals auto-extraction behavior"
```

---

### Task 3: Migrate Batch 1 — smallest features (Family, Legal, Settings, Profile, About)

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Components/ParentFamilyCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Components/FamilyMemberCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Views/ParentOnboardingWizardView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Views/FamilyManagementPlayerView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Components/LegalEmailLink.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Views/SettingsView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Profile/Views/ProfileView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/About/Views/AboutView.swift`

(Note: `Timeline`, `Landing`, `Onboarding` were also in scope for this batch per the design doc but have zero non-literal `accessibilityLabel` sites — confirmed via grep, no changes needed there.)

**Interfaces:**
- Consumes: catalog from Task 1, ternary decision from Task 2.
- Produces: nothing consumed by later tasks — each feature batch is independent.

**The transformation rule** (apply to every site listed in Step 1 below): a call site that passes a non-literal expression to `.accessibilityLabel(...)` — whether a computed property reference, a plain interpolated string, or (if Task 2 decided ternaries need it) a ternary — gets wrapped in `String(localized:)`. If the expression is a reference to a computed property (e.g. `cardAccessibilityLabel`), wrap the property's `return`/body expression at its *definition*, not the call site, so the type stays `String` at the call site (unchanged) but the value now routes through `String(localized:)`.

- [ ] **Step 1: Rewrite each site**

`ParentFamilyCard.swift` and `FamilyMemberCard.swift` — these reference computed properties `cardAccessibilityLabel` / `removeAccessibilityLabel`. Read the property definition in each file and wrap its returned string expression in `String(localized:)`. Example for `FamilyMemberCard.swift`'s `cardAccessibilityLabel` (wrap whatever interpolated expression the property currently returns):

```swift
// Before (inside the computed property body)
return "\(member.name), \(member.role)"

// After
return String(localized: "\(member.name), \(member.role)")
```

`ParentOnboardingWizardView.swift:235` and `FamilyManagementPlayerView.swift:63`:

```swift
// Before
.accessibilityLabel(FamilyUtilities.formatCodeForVoiceOver(code))

// After — wrap at the call site since this isn't a computed property, it's a static utility call
.accessibilityLabel(String(localized: "\(FamilyUtilities.formatCodeForVoiceOver(code))"))
```

`LegalEmailLink.swift:25`:

```swift
// Before
.accessibilityLabel("Email \(email.replacing("@", with: " at ").replacing(".", with: " dot "))")

// After
.accessibilityLabel(String(localized: "Email \(email.replacing("@", with: " at ").replacing(".", with: " dot "))"))
```

`SettingsView.swift:57` (ternary — apply per Task 2's decision) and `SettingsView.swift:289`:

```swift
// Before (line 289)
.accessibilityLabel(badgeStatus.map { "\(title): \($0.label). \(description)" } ?? "\(title): \(description)")

// After
.accessibilityLabel(
    badgeStatus.map { String(localized: "\(title): \($0.label). \(description)") }
        ?? String(localized: "\(title): \(description)")
)
```

`ProfileView.swift` (5 sites, all ternaries of the form `condition ? "Literal A" : "Literal B or interpolated"`) — for each, if Task 2 confirmed ternaries auto-extract AND both branches are pure literals, leave unchanged; if either branch interpolates (lines 174, 313 do: `"Error: \(msg.text)"`), wrap that branch:

```swift
// Before (line 174)
.accessibilityLabel(msg.isSuccess ? "Saved successfully" : "Error: \(msg.text)")

// After
.accessibilityLabel(msg.isSuccess ? "Saved successfully" : String(localized: "Error: \(msg.text)"))
```

Lines 190, 259, 329 are ternaries of two pure literals — leave unchanged if Task 2 confirmed auto-extraction, otherwise wrap the whole ternary in `String(localized:)`.

`AboutView.swift:72` — ternary of two pure literals, same rule as above.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/FamilyMemberCardTests -only-testing:TheRecruitingCompassTests/SettingsViewTests -only-testing:TheRecruitingCompassTests/ProfileViewModelTests -quiet` (adjust test target names to whatever actually exists for these views — `grep -rl "FamilyMemberCard\|SettingsView\|ProfileView" TheRecruitingCompassTests --include="*.swift"` first to find them; if no dedicated a11y tests exist for a file, skip it, the full-suite run in Task 9 is the final gate).
Expected: PASS, no failures.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Family TheRecruitingCompass/TheRecruitingCompass/Features/Legal TheRecruitingCompass/TheRecruitingCompass/Features/Settings TheRecruitingCompass/TheRecruitingCompass/Features/Profile TheRecruitingCompass/TheRecruitingCompass/Features/About
git commit -m "refactor: route Family/Legal/Settings/Profile/About a11y labels through String(localized:)"
```

---

### Task 4: Migrate Batch 2 — CommunicationTemplates, ActivityFeed, Tasks, Notifications, Help, Analytics

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Components/TemplateCardView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Views/TemplateEditorView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Views/CommunicationTemplatesView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/ActivityFeed/Components/ActivityEventItem.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/ActivityFeed/Components/RecentActivityWidget.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/ActivityFeed/Views/ActivityFeedView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Components/TaskCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Components/NotificationEmptyState.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Components/NotificationToggleChip.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Components/NotificationCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Components/NotificationFilterChips.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Components/NotificationBulkActions.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Help/Components/HelpSectionHeader.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Help/Components/HelpCallout.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Help/Components/HelpBadge.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Help/Views/HelpCenterView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Help/Components/HelpFeedbackView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Help/Components/HelpImageSlot.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Analytics/Components/StatCardView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Analytics/Components/FunnelChartView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Analytics/Components/PieChartView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Analytics/Components/ScatterChartView.swift`

**Interfaces:**
- Consumes: catalog from Task 1, ternary decision from Task 2, transformation rule established in Task 3.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Re-run the site inventory for this batch to catch drift**

Run: `grep -rnE 'accessibilityLabel\(' TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates TheRecruitingCompass/TheRecruitingCompass/Features/ActivityFeed TheRecruitingCompass/TheRecruitingCompass/Features/Tasks TheRecruitingCompass/TheRecruitingCompass/Features/Notifications TheRecruitingCompass/TheRecruitingCompass/Features/Help TheRecruitingCompass/TheRecruitingCompass/Features/Analytics --include="*.swift" | grep -v 'accessibilityLabel("[^"]*")'`

Every result is one of two shapes:
1. **Reference to a computed property** (e.g. `.accessibilityLabel(cardAccessibilityLabel)`, `.accessibilityLabel(accessibilityLabelText)`, `.accessibilityLabel(funnelAccessibilityLabel)`) — go to that property's definition in the same file and wrap its returned expression in `String(localized:)`, same as Task 3 Step 1's `FamilyMemberCard` example. This covers the majority of this batch: `TemplateCardView`, `TemplateEditorView`, `ActivityEventItem`, `RecentActivityWidget` (×2), `TaskCard` (×2), `NotificationEmptyState`, `NotificationCard`, `NotificationBulkActions` (×2), `HelpCallout`, `StatCardView`, `FunnelChartView`, `PieChartView`, `ScatterChartView`.
2. **Direct call with an interpolated literal or a function/static-method call** — wrap at the call site. Concrete cases in this batch:

`CommunicationTemplatesView.swift:61` — `.accessibilityLabel(title)` where `title` is a `let`/parameter (not computed) holding plain dynamic text: wrap at the call site:
```swift
.accessibilityLabel(String(localized: "\(title)"))
```

`NotificationToggleChip.swift:8-26` — a static function that builds the label:
```swift
// Before
static func accessibilityLabel(for label: String, isActive: Bool) -> String {
    "\(label), \(isActive ? "active" : "inactive")"
}

// After
static func accessibilityLabel(for label: String, isActive: Bool) -> String {
    String(localized: "\(label), \(isActive ? "active" : "inactive")")
}
```
(the two call sites in `NotificationFilterChips.swift:13,16` need no change — they call this function, which now returns a localized string internally.)

`HelpSectionHeader.swift:27`:
```swift
// Before
.accessibilityLabel(badge.map { "\(title), \($0.label) badge" } ?? title)

// After
.accessibilityLabel(badge.map { String(localized: "\(title), \($0.label) badge") } ?? String(localized: "\(title)"))
```

`HelpBadge.swift:44` — `.accessibilityLabel(type.label)` where `type.label` is an enum's `String` property: wrap at call site: `.accessibilityLabel(String(localized: "\(type.label)"))`.

`HelpCenterView.swift:25` — `.accessibilityLabel(section.title)`: same pattern, wrap at call site.

`HelpFeedbackView.swift:59` — `.accessibilityLabel(errorMessage)` where `errorMessage` is dynamic user-facing text from validation: wrap at call site.

`HelpImageSlot.swift:30` — `.accessibilityLabel(caption)` where `caption` is a view parameter: wrap at call site.

`ActivityFeedView.swift:119` — `.accessibilityLabel(pageIndicatorAccessibilityLabel(...))`, a function call with arguments. Find `pageIndicatorAccessibilityLabel`'s definition in the same file and wrap its returned expression in `String(localized:)`, same as the static-function pattern above.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

`grep -rl "TemplateCardView\|ActivityEventItem\|TaskCard\|NotificationToggleChip\|HelpSectionHeader\|StatCardView" TheRecruitingCompassTests --include="*.swift"` to find relevant test files, run those with `-only-testing:`; if none exist for a given file, rely on the full-suite run in Task 9.
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates TheRecruitingCompass/TheRecruitingCompass/Features/ActivityFeed TheRecruitingCompass/TheRecruitingCompass/Features/Tasks TheRecruitingCompass/TheRecruitingCompass/Features/Notifications TheRecruitingCompass/TheRecruitingCompass/Features/Help TheRecruitingCompass/TheRecruitingCompass/Features/Analytics
git commit -m "refactor: route CommunicationTemplates/ActivityFeed/Tasks/Notifications/Help/Analytics a11y labels through String(localized:)"
```

---

### Task 5: Migrate Batch 3 — Interactions, Performance, Offers, Preferences

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Components/InteractionFilterBar.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Components/AttachmentIndicator.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Views/AddInteractionView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Components/AnalyticsCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Components/InteractionCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Components/SuccessToast.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Components/LatestMetricCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Components/PerformanceChartView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Components/MetricFormView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Offers/Components/OfferFilterBar.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Offers/Components/OfferCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Offers/Components/ScholarshipCalculatorView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Offers/Components/AddOfferForm.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Offers/Components/OfferSummaryCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Offers/Components/OfferFinancialSummary.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/PreferenceLoadingOverlay.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/ToggleCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/PreferenceRow.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/SchoolPreferencesView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/PositionChipsView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/PreferenceSuccessToast.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/HomeLocationView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/DashboardCustomizationView.swift`

**Interfaces:**
- Consumes: catalog from Task 1, ternary decision from Task 2, transformation rule established in Task 3/4.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Re-run the site inventory and apply the rule**

Run: `grep -rnE 'accessibilityLabel\(' TheRecruitingCompass/TheRecruitingCompass/Features/Interactions TheRecruitingCompass/TheRecruitingCompass/Features/Performance TheRecruitingCompass/TheRecruitingCompass/Features/Offers TheRecruitingCompass/TheRecruitingCompass/Features/Preferences --include="*.swift" | grep -v 'accessibilityLabel("[^"]*")'`

Apply the same two-shape rule as Task 4 Step 1. Notable concrete cases to get exactly right:

`LatestMetricCard.swift:42`:
```swift
// Before
.accessibilityLabel("\(metric.displayName), \(metric.formattedValue), recorded \(metric.formattedDate)\(metric.verified ? ", verified" : "")")

// After
.accessibilityLabel(String(localized: "\(metric.displayName), \(metric.formattedValue), recorded \(metric.formattedDate)\(metric.verified ? ", verified" : "")"))
```

`PerformanceChartView.swift:46`:
```swift
// Before
.accessibilityLabel("Performance chart for \(metricType?.displayName ?? "metrics"), showing \(metrics.count) data points")

// After
.accessibilityLabel(String(localized: "Performance chart for \(metricType?.displayName ?? "metrics"), showing \(metrics.count) data points"))
```

`AddOfferForm.swift:91`:
```swift
// Before
.accessibilityLabel("Form errors: \(formState.validationErrors.joined(separator: ", "))")

// After
.accessibilityLabel(String(localized: "Form errors: \(formState.validationErrors.joined(separator: ", "))"))
```

`OfferSummaryCard.swift:24`:
```swift
// Before
.accessibilityLabel("\(count) \(title) offer\(count == 1 ? "" : "s")")

// After
.accessibilityLabel(String(localized: "\(count) \(title) offer\(count == 1 ? "" : "s")"))
```

`ScholarshipCalculatorView.swift:94` (ternary — apply per Task 2's decision; `"Hide scholarship calculator"` / `"Scholarship Calculator"` are both pure literals).

`ToggleCard.swift:60`:
```swift
// Before
.accessibilityLabel(isComingSoon ? "\(label) coming soon" : "\(label) \(isOn ? "enabled" : "disabled")")

// After
.accessibilityLabel(
    isComingSoon
        ? String(localized: "\(label) coming soon")
        : String(localized: "\(label) \(isOn ? "enabled" : "disabled")")
)
```

`PositionChipsView.swift:79`:
```swift
// Before
.accessibilityLabel("\(title), \(isSelected ? "selected" : "not selected")")

// After
.accessibilityLabel(String(localized: "\(title), \(isSelected ? "selected" : "not selected")"))
```

`PreferenceRow.swift:43`, `SchoolPreferencesView.swift:99`, `DashboardCustomizationView.swift:61,141` — ternaries of two pure literals, apply per Task 2's decision.

All remaining sites in this batch (`InteractionFilterBar`, `AttachmentIndicator`, `AddInteractionView`, `AnalyticsCard`, `InteractionCard`, `SuccessToast`, `MetricFormView`, `OfferFilterBar`, `OfferCard`, `OfferFinancialSummary`, `PreferenceLoadingOverlay`, `PreferenceSuccessToast`, `HomeLocationView`) reference computed properties or plain `let`/parameter values — apply the "wrap at definition" or "wrap at call site" rule from Task 4 Step 1 depending on which shape each one is.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

`grep -rl "OfferCard\|OfferSummaryCard\|LatestMetricCard\|PerformanceChartView\|ToggleCard\|PositionChipsView" TheRecruitingCompassTests --include="*.swift"`, run those with `-only-testing:`.
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Interactions TheRecruitingCompass/TheRecruitingCompass/Features/Performance TheRecruitingCompass/TheRecruitingCompass/Features/Offers TheRecruitingCompass/TheRecruitingCompass/Features/Preferences
git commit -m "refactor: route Interactions/Performance/Offers/Preferences a11y labels through String(localized:)"
```

---

### Task 6: Migrate Batch 4 — Auth, Documents, Coaches, Events, Dashboard

**Files:** (discovered fresh in Step 1 — these features weren't grepped during planning; follow the same rule)

**Interfaces:**
- Consumes: catalog from Task 1, ternary decision from Task 2, transformation rule established in Task 3/4/5.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Enumerate non-literal sites in this batch**

Run: `grep -rnE 'accessibilityLabel\(' TheRecruitingCompass/TheRecruitingCompass/Features/Auth TheRecruitingCompass/TheRecruitingCompass/Features/Documents TheRecruitingCompass/TheRecruitingCompass/Features/Coaches TheRecruitingCompass/TheRecruitingCompass/Features/Events TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard --include="*.swift" | grep -v 'accessibilityLabel("[^"]*")'`

For each result, classify and fix using the exact two rules established in Task 4 Step 1 / Task 5 Step 1:
- Reference to a computed property (`.accessibilityLabel(someAccessibilityLabel)`) → open that file, find the property, wrap its returned string expression in `String(localized:)`.
- Direct interpolated literal, ternary, or function/static-method call → wrap at the call site (or at the function's return statement) in `String(localized:)`, preserving the exact interpolation content — do not alter the wording, only wrap it.
- Pure-literal ternary → apply per Task 2's decision (no change if auto-extraction confirmed).

Read each flagged file with the Read tool before editing to get the exact surrounding code (property name, indentation, exact literal text) — do not guess at content not shown by the grep output.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

Find relevant test files: `grep -rl "LoginView\|SignupView\|DocumentCard\|CoachCard\|EventCard\|DashboardView" TheRecruitingCompassTests --include="*.swift"`, run with `-only-testing:`.
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Auth TheRecruitingCompass/TheRecruitingCompass/Features/Documents TheRecruitingCompass/TheRecruitingCompass/Features/Coaches TheRecruitingCompass/TheRecruitingCompass/Features/Events TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard
git commit -m "refactor: route Auth/Documents/Coaches/Events/Dashboard a11y labels through String(localized:)"
```

---

### Task 7: Migrate Batch 5 — Schools (largest feature, 38 files)

**Files:** (discovered fresh in Step 1)

**Interfaces:**
- Consumes: catalog from Task 1, ternary decision from Task 2, transformation rule established in prior tasks.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Enumerate non-literal sites**

Run: `grep -rnE 'accessibilityLabel\(' TheRecruitingCompass/TheRecruitingCompass/Features/Schools --include="*.swift" | grep -v 'accessibilityLabel("[^"]*")'`

Given the size of this feature, work file-by-file: for each match, Read the file, classify (computed-property reference vs. direct interpolation/ternary/function-call), and apply the same rule as Task 6 Step 1. Because this is the largest batch, consider splitting the actual edit work into 2-3 sub-commits by subdirectory (e.g. `Schools/Views` then `Schools/Components`) if the diff grows unwieldy — but run the build/test gate (Steps 2-3) before each sub-commit, not just once at the end.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

`grep -rl "School" TheRecruitingCompassTests --include="*.swift" | grep -i school`, run with `-only-testing:`.
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools
git commit -m "refactor: route Schools a11y labels through String(localized:)"
```

---

### Task 8: Migrate Batch 6 — Shared/Components (cross-feature)

**Files:** (discovered fresh in Step 1)

**Interfaces:**
- Consumes: catalog from Task 1, ternary decision from Task 2, transformation rule established in prior tasks.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Enumerate non-literal sites**

Run: `grep -rnE 'accessibilityLabel\(' TheRecruitingCompass/TheRecruitingCompass/Shared --include="*.swift" | grep -v 'accessibilityLabel("[^"]*")'`

Apply the same classify-and-fix rule as Task 6 Step 1. These are reusable components used across many features (`WarningBanner`, `Toast`, `SessionExpiredSheet`, `OfflineBanner`, `LoadingStateView`, `ListRowSkeleton`, `InterestResultCard`, `InlineErrorView`, `InfoRow`, `SchoolPicker`, `OtherCoachSheet`, `FormFieldWrapper`, `FormErrorSummary`, `FieldError`, `CharacterCountView`, `AddCoachSheet`, `FilterMenuButton`, `FilteredResultsHeader`, `FilterChipContainer`, `FilterChip`, and any others the grep turns up) — extra care here since a mistake affects every feature that uses the component. Read each file fully before editing.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Shared
git commit -m "refactor: route Shared/Components a11y labels through String(localized:)"
```

---

### Task 9: Full-suite verification and close-out

**Files:** none (verification only).

**Interfaces:**
- Consumes: all prior tasks' committed changes.

- [ ] **Step 1: Full clean build**

Run: `cd TheRecruitingCompass && xcodebuild clean build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors or warnings beyond the pre-existing baseline.

- [ ] **Step 2: Full unit test suite**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests`
Expected: `** TEST SUCCEEDED **`, same pass count as the pre-migration baseline (3720/3720 at the time this plan was written — confirm the current count matches, adjusting only for any tests added/removed on `main` since).

- [ ] **Step 3: Confirm no remaining un-classified sites**

Run: `grep -rnE 'accessibilityLabel\(' TheRecruitingCompass/TheRecruitingCompass --include="*.swift" | grep -v 'accessibilityLabel("[^"]*")' | grep -v 'String(localized:'`

Expected: only pure-literal ternaries remain unwrapped (if Task 2 confirmed those need no change) — every interpolated/computed/function-call site should now show `String(localized:` in its line. If anything unexpected remains, go back and fix it (do not close out with known gaps).

- [ ] **Step 4: Update project memory**

Update `CLAUDE.local.md` (worktree copy) and `MEMORY.md` (if used) to record: Phase 6a complete, catalog exists, 661 a11y-label sites migrated, `Text()` sites (645) remain as a future phase.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: Phase 6a complete — localization catalog + a11y-label migration verified

Full clean build + unit suite green (3720/3720). All accessibilityLabel
call sites now catalog-backed (literal auto-extraction + manual
String(localized:) wrapping for interpolated/computed sites).
Text() call sites (645) remain out of scope — future phase."
```
