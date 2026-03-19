# UIHostingController Accessibility Test Fix Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate 62 permanently-skipping accessibility unit tests that use `UIHostingController` — an approach that doesn't work for SwiftUI accessibility introspection.

**Architecture:** These tests try to verify accessibility labels by hosting SwiftUI views in `UIHostingController` and extracting labels via the accessibility API. SwiftUI's accessibility tree is not exposed this way in unit tests. The fix is to **delete** these test files (they provide zero coverage) and trust the real E2E accessibility tests in `TheRecruitingCompassUITests` which use `XCUIApplication` and DO see the accessibility tree.

**Tech Stack:** Swift, XCTest

---

## Context

21 unit test files use `UIHostingController` and include:
```swift
try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
```

This skip fires **every time** — the labels are always empty. These tests have never passed.
They cover 62 test cases across features like FamilyManagement, Notifications, Interactions, etc.

The corresponding E2E accessibility tests in `TheRecruitingCompassUITests` (e.g., `FamilyManagementParentFlowsE2ETests`, `NotificationsE2ETests`) test the same accessibility properties via the real running app and DO work (they skip only due to Supabase, which Plan A fixes).

**Recommendation: Delete the UIHostingController tests.** They are dead code.

---

## Files to Delete

Find all affected files:

```bash
grep -rn "UIHostingController\|labels.isEmpty" \
  TheRecruitingCompass/TheRecruitingCompassTests/ \
  --include="*.swift" -l
```

Expected 21 files, all in `TheRecruitingCompassTests/` under subdirectories like:
- `Features/Settings/Accessibility/FamilyManagementAccessibilityTests.swift`
- `Features/Notifications/Accessibility/*.swift`
- `Accessibility/*.swift` (various)

---

## Task 1: Audit and delete UIHostingController test files

- [ ] **Step 1: Get the full list of files to delete**

```bash
grep -rn "UIHostingController" \
  TheRecruitingCompass/TheRecruitingCompassTests/ \
  --include="*.swift" -l
```

Review each file. Verify it ONLY contains `UIHostingController`-based tests (no other test methods worth keeping).

- [ ] **Step 2: Confirm the skip pattern is universal in each file**

For each file, check what percentage of tests skip:

```bash
for f in $(grep -rn "UIHostingController" \
  TheRecruitingCompass/TheRecruitingCompassTests/ \
  --include="*.swift" -l); do
  total=$(grep -c "func test" "$f" 2>/dev/null || echo 0)
  skips=$(grep -c "XCTSkipIf" "$f" 2>/dev/null || echo 0)
  echo "$skips/$total skips: $f"
done
```

If a file has tests WITHOUT `XCTSkipIf` (i.e., tests that pass), do NOT delete it — extract the passing tests first.

- [ ] **Step 3: Delete the files**

```bash
# Example - adjust paths based on Step 1 output
grep -rn "UIHostingController" \
  TheRecruitingCompass/TheRecruitingCompassTests/ \
  --include="*.swift" -l | xargs rm
```

- [ ] **Step 4: Verify build still passes**

```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Verify test count decreased by ~62**

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests \
  2>&1 | grep -E "Executed [0-9]+ tests?"
```

Expected: ~62 fewer tests than before.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(tests): remove UIHostingController accessibility tests

These 62 tests have never passed — UIHostingController does not expose
the SwiftUI accessibility tree in unit tests, causing every test to skip
with 'SwiftUI accessibility labels not accessible via UIHostingController'.

The same accessibility properties are verified by the E2E accessibility
tests in TheRecruitingCompassUITests which use XCUIApplication and DO
see the full accessibility tree when the app runs live."
```

---

## Alternative: Keep but convert to E2E tests (optional, higher effort)

If the accessibility assertions in these files cover edge cases NOT tested by the existing E2E accessibility tests, consider converting them rather than deleting.

The pattern to convert a UIHostingController unit test to a UI test:

**Before (unit test, always skips):**
```swift
func testFamilyCode_HasVoiceOverFriendlyLabel() throws {
  let view = FamilyCodeView(code: "ABC-123")
  let hosting = UIHostingController(rootView: view)
  let labels = hosting.view.accessibilityLabels // always empty
  try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible")
  XCTAssertTrue(labels.contains("Family code: ABC 123"))
}
```

**After (UI test, works):**
```swift
// In TheRecruitingCompassUITests/Features/Family/
func testFamilyCode_HasVoiceOverFriendlyLabel() throws {
  // Login required
  guard app.waitForLogin(timeout: 10) else {
    throw XCTSkip("Login failed - Supabase may not be configured")
  }
  // Navigate to Family Management
  app.tabBars.buttons["Settings"].tap()
  app.cells["Family Management"].tap()

  let familyCodeElement = app.staticTexts.matching(
    NSPredicate(format: "label CONTAINS 'Family code'")
  ).firstMatch
  XCTAssertTrue(familyCodeElement.waitForExistence(timeout: 5))
}
```

This is higher effort but provides real coverage. Do this only if the UIHostingController tests cover unique scenarios missing from existing E2E tests.

---

## Expected Outcome

| State | Before | After |
|---|---|---|
| Total skipped | 62 (UIHostingController) | 0 |
| Total tests | ~3,900 | ~3,840 |
| Test suite health | 62 dead tests | Clean |
