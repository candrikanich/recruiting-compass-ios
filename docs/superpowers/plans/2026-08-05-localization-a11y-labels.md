# Phase 6a — Localization catalog + accessibility-label migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Localizable.xcstrings` String Catalog to the app target and make every `accessibilityLabel` call site catalog-backed, staying English-only.

**Architecture:** Every `accessibilityLabel` argument — literal, ternary, or interpolated — gets wrapped in `String(localized:)`, uniformly. (Originally the plan assumed literal-string sites needed zero code change via Xcode's build-time auto-extraction; Task 1's implementation run disproved that for this repo's CLI-only `xcodebuild` workflow — see the design doc's "REVISED 2026-08-05" section. Auto-extraction only fires through Xcode's GUI-driven incremental build, never plain `xcodebuild`, so the catalog stays structurally present but empty of real entries until someone opens Xcode at least once — an accepted, explicit gap, not this plan's job to fix.) 545 sites (512 literals + 33 ternaries-of-literals) get a mechanical regex wrap in one pass; the remaining ~116 interpolated/computed-property sites get hand-rewritten feature batch by feature batch, unchanged from the original plan.

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

### Task 1: Add the String Catalog

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings`

**Interfaces:**
- Produces: a target-member `.xcstrings` catalog file. No later task depends on its *contents* — CLI builds don't populate it (confirmed: a from-scratch `xcodebuild clean build` produces zero entries, even for known-present literals like `"Sign in to account"`). It exists as the structural placeholder a future Xcode-GUI build or `xcodebuild -exportLocalizations` run will populate. Do not attempt to verify or force population in this task — that's out of scope.

- [ ] **Step 1: Create the catalog file**

Create `TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings` with the minimal valid empty-catalog JSON:

```json
{
  "sourceLanguage" : "en",
  "strings" : {},
  "version" : "1.0"
}
```

- [ ] **Step 2: Clean build to confirm the catalog doesn't break anything**

Run: `cd TheRecruitingCompass && xcodebuild clean build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`

Expected: build succeeds with no new errors (same warnings as before are fine). Do not check the catalog's contents — an empty catalog after this build is expected and correct, not a failure.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings
git commit -m "feat: add Localizable.xcstrings String Catalog

Structural placeholder for future localization. Auto-extraction only
fires through Xcode's GUI-driven incremental build, never plain
xcodebuild (confirmed empirically) — catalog stays empty of real
entries until someone builds via Xcode.app or runs
xcodebuild -exportLocalizations, both out of this plan's scope."
```

---

### Task 2: Mechanical wrap of literal + ternary-of-literal accessibilityLabel sites

**Files:**
- Create (temporary, delete after use): a one-off Python script, e.g. `scripts/wrap-a11y-literals.py`
- Modify: every `.swift` file under `TheRecruitingCompass/TheRecruitingCompass` containing a plain-literal or pure-literal-ternary `accessibilityLabel(...)` call (512 + 33 = 545 sites, discovered by the script itself — do not hand-enumerate).

**Interfaces:**
- Consumes: nothing from Task 1 except the catalog's existence (this task doesn't touch it).
- Produces: nothing consumed by later tasks — this task and the feature-batch tasks (3-8) touch disjoint sets of call sites (this task's regex only matches sites where every branch is a plain string literal with no interpolation or escaped quotes; anything else is untouched and remains for the feature-batch tasks).

- [ ] **Step 1: Write the transform script**

Create `scripts/wrap-a11y-literals.py`:

```python
#!/usr/bin/env python3
"""One-off mechanical transform: wrap accessibilityLabel literal and
pure-literal-ternary arguments in String(localized:). Run once, then delete.
"""
import re
import subprocess
import sys

ROOT = "TheRecruitingCompass/TheRecruitingCompass"

# Matches: .accessibilityLabel("literal") — no backslashes/interpolation inside the string
LITERAL = re.compile(r'\.accessibilityLabel\("([^"\\]*)"\)')

# Matches: .accessibilityLabel(cond ? "literal A" : "literal B")
# cond may be any expression not itself containing a top-level '?' or ':' outside brackets —
# keep this conservative: only match when cond has no parens/brackets, to avoid
# misparsing nested ternaries or function calls as the condition.
TERNARY = re.compile(
    r'\.accessibilityLabel\(([A-Za-z_][A-Za-z0-9_.]*)\s*\?\s*"([^"\\]*)"\s*:\s*"([^"\\]*)"\)'
)

def wrap_literal(m):
    return f'.accessibilityLabel(String(localized: "{m.group(1)}"))'

def wrap_ternary(m):
    cond, a, b = m.group(1), m.group(2), m.group(3)
    return f'.accessibilityLabel({cond} ? String(localized: "{a}") : String(localized: "{b}"))'

def process_file(path):
    with open(path, "r", encoding="utf-8") as f:
        original = f.read()
    text = TERNARY.sub(wrap_ternary, original)
    text = LITERAL.sub(wrap_literal, text)
    if text != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        return True
    return False

def main():
    result = subprocess.run(
        ["grep", "-rl", "-E", r"accessibilityLabel\(", ROOT, "--include=*.swift"],
        capture_output=True, text=True,
    )
    files = [f for f in result.stdout.splitlines() if f]
    changed = 0
    for path in files:
        if process_file(path):
            changed += 1
    print(f"Modified {changed} files")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the script**

Run: `python3 scripts/wrap-a11y-literals.py`

Expected: prints `Modified N files` where N is roughly 150-250 (many files have multiple sites, some sites in the same file).

- [ ] **Step 3: Sanity-check the diff before building**

Run: `git diff --stat` and skim `git diff | head -200`. Every changed line should show a `.accessibilityLabel("...")` becoming `.accessibilityLabel(String(localized: "..."))`, or a ternary's two branches each individually wrapped — the string content inside the quotes must be byte-for-byte unchanged from before. If anything looks wrong (a literal's text altered, a non-accessibilityLabel line touched, a computed-property call like `.accessibilityLabel(cardAccessibilityLabel)` incorrectly matched), STOP: `git checkout -- .`, fix the script's regex, and re-run from Step 2. Do not proceed to build with a bad diff.

- [ ] **Step 4: Confirm expected count**

Run: `grep -rc 'accessibilityLabel(String(localized:' TheRecruitingCompass/TheRecruitingCompass --include="*.swift" | awk -F: '{sum+=$2} END {print sum}'`

Expected: a number in the 500s (should land close to 545 — literal sites plus pure-literal-ternary sites the regex matched; some ternaries with more complex conditions may not match this conservative regex and will remain for manual handling in the feature-batch tasks, which is fine).

- [ ] **Step 5: Delete the script**

The script is a one-off — it must not remain in the repo (it has no ongoing purpose and running it again on already-wrapped code would double-wrap).

Run: `rm scripts/wrap-a11y-literals.py`

- [ ] **Step 6: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`

Expected: no new errors. `String(localized:)` returns `String`, matching what `.accessibilityLabel(_:)` already accepted for these literal `LocalizedStringKey`-typed calls — this is a mechanical, type-safe substitution.

- [ ] **Step 7: Run the full unit suite**

This touches ~150-250 files across the whole app — worth the full gate once, rather than guessing which tests are affected.

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests`

Expected: `** TEST SUCCEEDED **`, same pass count as before this task (3720/3720 as of this plan's writing). If the sim-launch flake (`RBSRequestErrorDomain Code=5`) recurs, follow the Global Constraints retry guidance before treating anything as a real failure.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: mechanically wrap literal a11y labels in String(localized:)

Wraps every accessibilityLabel(\"literal\") and accessibilityLabel(cond
? \"A\" : \"B\") call site (~545 sites) in String(localized:), applied
via a one-off script (deleted after running). Uniform with the
interpolated/computed sites the following feature-batch tasks handle
by hand. Full build + unit suite verified green."
```

---

### Task 3: Migrate Batch 1 — smallest features (Family, Legal, Settings, Profile, About)

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Components/ParentFamilyCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Components/FamilyMemberCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Views/ParentOnboardingWizardView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Views/FamilyManagementPlayerView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Components/LegalEmailLink.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Views/SettingsView.swift` (line 289 only — line 57 already handled by Task 2)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Profile/Views/ProfileView.swift` (lines 174, 313 only — lines 190, 259, 329 already handled by Task 2)

(Note: `Timeline`, `Landing`, `Onboarding` were also in scope for this batch — an initial grep pass incorrectly reported zero non-literal `accessibilityLabel` sites for them due to a since-corrected grep blind spot (see the design doc's "Localization conventions" section); their actual sites were fixed in the final-review fix wave, not in this task's original commit. `AboutView.swift` had exactly one site, a pure-literal ternary, already handled by Task 2 — no changes needed here either.)

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

`SettingsView.swift:57` — a pure-literal ternary, already wrapped by Task 2's mechanical pass; skip it. `SettingsView.swift:289` is not pure-literal (uses `.map { }` with interpolation) so Task 2's regex didn't touch it — still needs the manual rewrite below:

```swift
// Before (line 289)
.accessibilityLabel(badgeStatus.map { "\(title): \($0.label). \(description)" } ?? "\(title): \(description)")

// After
.accessibilityLabel(
    badgeStatus.map { String(localized: "\(title): \($0.label). \(description)") }
        ?? String(localized: "\(title): \(description)")
)
```

`ProfileView.swift` — 5 ternary sites. Lines 190, 259, 329 are pure-literal ternaries, already wrapped by Task 2's mechanical pass; skip them. Lines 174 and 313 have an interpolated branch (`"Error: \(msg.text)"`), which Task 2's regex doesn't match — still need the manual rewrite:

```swift
// Before (line 174)
.accessibilityLabel(msg.isSuccess ? "Saved successfully" : "Error: \(msg.text)")

// After
.accessibilityLabel(msg.isSuccess ? "Saved successfully" : String(localized: "Error: \(msg.text)"))
```

(line 313 follows the identical pattern.)

`AboutView.swift:72` — pure-literal ternary, already wrapped by Task 2's mechanical pass; skip it.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/FamilyMemberCardTests -only-testing:TheRecruitingCompassTests/SettingsViewTests -only-testing:TheRecruitingCompassTests/ProfileViewModelTests -quiet` (adjust test target names to whatever actually exists for these views — `grep -rl "FamilyMemberCard\|SettingsView\|ProfileView" TheRecruitingCompassTests --include="*.swift"` first to find them; if no dedicated a11y tests exist for a file, skip it, the full-suite run in Task 9 is the final gate).
Expected: PASS, no failures.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Family TheRecruitingCompass/TheRecruitingCompass/Features/Legal TheRecruitingCompass/TheRecruitingCompass/Features/Settings TheRecruitingCompass/TheRecruitingCompass/Features/Profile
git commit -m "refactor: route Family/Legal/Settings/Profile a11y labels through String(localized:)"
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

`ScholarshipCalculatorView.swift:94` — pure-literal ternary (`"Hide scholarship calculator"` / `"Scholarship Calculator"`), already wrapped by Task 2's mechanical pass; skip it.

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

`PreferenceRow.swift:43`, `SchoolPreferencesView.swift:99`, `DashboardCustomizationView.swift:61,141` — ternaries of two pure literals, already wrapped by Task 2's mechanical pass; skip them.

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
- Pure-literal ternary → already wrapped by Task 2's mechanical pass; if grep still shows one unwrapped here, Task 2's regex missed it (e.g. a condition with a dotted path or parens) — wrap it manually following the same pattern.

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

Expected: **zero matches**. Every `accessibilityLabel` call site — literal, ternary, interpolated, or computed-property-backed — should now show `String(localized:` somewhere in its line or (for computed properties) at the property's definition. If anything remains, go back and fix it (do not close out with known gaps).

- [ ] **Step 4: Update project memory**

Update `CLAUDE.local.md` (worktree copy) and `MEMORY.md` (if used) to record: Phase 6a complete, catalog exists, 661 a11y-label sites migrated, `Text()` sites (645) remain as a future phase.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: Phase 6a complete — localization catalog + a11y-label migration verified

Full clean build + unit suite green (3720/3720). All accessibilityLabel
call sites now route through String(localized:) (mechanical wrap for
literals/ternaries, hand-rewrite for interpolated/computed sites).
Catalog population still requires a future Xcode-GUI build or
xcodebuild -exportLocalizations — out of this plan's scope.
Text() call sites (645) remain out of scope — future phase."
```
