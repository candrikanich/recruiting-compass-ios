# Player Profile Tab Reorganization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regroup Player Profile fields by purpose across iOS and web — Contact+Privacy+Social → Basics, High School → Academics, add `core_courses` + phone/email inputs to iOS, and collapse web's duplicate phone/email to one home.

**Architecture:** Pure UI relocation of fields that already exist in the `user_preferences` player JSON blob. No DB/migration. iOS: one new model field (`coreCourses`) + view moves across three tab files. Web: move DOM blocks between two tab components + rethread props from `player-details.vue`, rename one tab label.

**Tech Stack:** iOS — SwiftUI, `@Observable` MVVM, XCTest. Web — Nuxt 3 / Vue 3 `<script setup>`, Vitest + Vue Test Utils.

## Global Constraints

- No database schema or migration change. Every field keeps its existing JSON key in `user_preferences.data` (category `player`).
- Field JSON keys (verbatim): `phone`, `email`, `allow_share_phone`, `allow_share_email`, `core_courses`, `high_school`, `school_city`, `school_state`, `twitter_handle`, `instagram_handle`, `tiktok_handle`, `facebook_url`, `campus_size_preference`, `cost_sensitivity`.
- Core Courses rules (both platforms): max 20 entries; max 60 chars each; trim whitespace; no duplicates; Return/Enter adds; read-only role cannot add/remove.
- iOS builds must pass `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'` clean (run from `TheRecruitingCompass/`). Trust exit code, not a grep.
- iOS paths are double-nested: `TheRecruitingCompass/TheRecruitingCompass/...`.
- iOS Repo currently on branch `feat/player-basics-college-prefs`; keep committing there.
- Campus size / cost sensitivity stay in Basics. Athletics, History, Public Profile tabs unchanged. Recruiting DB IDs stay in Athletics.
- iOS `AcademicsSocialTab.swift` keeps its filename (avoids xcodeproj churn); only its content changes.
- Web tab `id` stays `academics`; only the display `name` changes.

---

## Phase A — iOS

### Task A1: Add `coreCourses` to the model

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Models/PlayerDetails.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/PlayerDetailsCodableTests.swift` (create if absent; otherwise add to the existing PlayerDetails test file)

**Interfaces:**
- Produces: `PlayerDetails.coreCourses: [String]?` mapped to JSON key `core_courses`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class PlayerDetailsCodableTests: XCTestCase {
    func testCoreCoursesRoundTrips() throws {
        let json = #"{"core_courses":["AP Chemistry","Honors English"]}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PlayerDetails.self, from: json)
        XCTAssertEqual(decoded.coreCourses, ["AP Chemistry", "Honors English"])

        let reencoded = try JSONEncoder().encode(decoded)
        let obj = try JSONSerialization.jsonObject(with: reencoded) as! [String: Any]
        XCTAssertEqual(obj["core_courses"] as? [String], ["AP Chemistry", "Honors English"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from `TheRecruitingCompass/`:
`xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PlayerDetailsCodableTests`
Expected: FAIL — `coreCourses` is not a member of `PlayerDetails`.

- [ ] **Step 3: Add the field + coding key**

In `PlayerDetails.swift`, add near the Academics group:

```swift
  // Academics
  var gpa: Double? // 0.0-5.0
  var satScore: Int? // 400-1600
  var actScore: Int? // 1-36
  var coreCourses: [String]? // AP/honors/notable courses (max 20)
```

Add to `CodingKeys`:

```swift
    case actScore = "act_score"
    case coreCourses = "core_courses"
```

- [ ] **Step 4: Run test to verify it passes**

Run the same command from Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Models/PlayerDetails.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/PlayerDetailsCodableTests.swift
git commit -m "feat(profile): add coreCourses to PlayerDetails model"
```

---

### Task A2: Core Courses chip editor component

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/CoreCoursesEditor.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/CoreCoursesLogicTests.swift`

**Interfaces:**
- Consumes: nothing from prior tasks except `PlayerDetails.coreCourses` (A1).
- Produces: `struct CoreCoursesEditor: View` with `init(courses: Binding<[String]>, isDisabled: Bool)`. Pure add/remove helpers `CoreCoursesEditor.normalizedToAdd(_:existing:) -> String?` (static, testable) returning the trimmed course to append or `nil` if invalid/duplicate/at-cap.

The static helper isolates the rules from SwiftUI so it is unit-testable without a host.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class CoreCoursesLogicTests: XCTestCase {
    func testTrimsAndAdds() {
        XCTAssertEqual(CoreCoursesEditor.normalizedToAdd("  AP Chem  ", existing: []), "AP Chem")
    }
    func testRejectsBlank() {
        XCTAssertNil(CoreCoursesEditor.normalizedToAdd("   ", existing: []))
    }
    func testRejectsDuplicate() {
        XCTAssertNil(CoreCoursesEditor.normalizedToAdd("AP Chem", existing: ["AP Chem"]))
    }
    func testRejectsAtCap() {
        let full = (1...20).map { "Course \($0)" }
        XCTAssertNil(CoreCoursesEditor.normalizedToAdd("Extra", existing: full))
    }
    func testTruncatesToSixtyChars() {
        let long = String(repeating: "x", count: 80)
        XCTAssertEqual(CoreCoursesEditor.normalizedToAdd(long, existing: [])?.count, 60)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/CoreCoursesLogicTests`
Expected: FAIL — `CoreCoursesEditor` not found.

- [ ] **Step 3: Implement the component**

```swift
import SwiftUI

struct CoreCoursesEditor: View {
    @Binding var courses: [String]
    let isDisabled: Bool
    @State private var newCourse: String = ""

    static let maxCourses = 20
    static let maxLength = 60

    /// Returns the normalized course to append, or nil if it must be rejected.
    static func normalizedToAdd(_ raw: String, existing: [String]) -> String? {
        let trimmed = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        guard !trimmed.isEmpty else { return nil }
        guard existing.count < maxCourses else { return nil }
        guard !existing.contains(trimmed) else { return nil }
        return trimmed
    }

    private func add() {
        guard let course = Self.normalizedToAdd(newCourse, existing: courses) else { return }
        courses.append(course)
        newCourse = ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AP, honors, or notable courses for your recruiting profile.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !courses.isEmpty {
                FlowChips(courses: $courses, isDisabled: isDisabled)
            }

            if !isDisabled && courses.count < Self.maxCourses {
                HStack(spacing: 8) {
                    TextField("e.g., AP Chemistry", text: $newCourse)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .buttonStyle(.borderedProminent)
                        .disabled(newCourse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else if courses.count >= Self.maxCourses {
                Text("Maximum 20 courses added.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

private struct FlowChips: View {
    @Binding var courses: [String]
    let isDisabled: Bool

    var body: some View {
        // Simple wrapping layout via SwiftUI's native flow (iOS 16+: use a lazy grid fallback).
        FlexibleWrap(items: courses) { course in
            HStack(spacing: 6) {
                Text(course).font(.subheadline)
                if !isDisabled {
                    Button {
                        courses.removeAll { $0 == course }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(course)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
        }
    }
}
```

Add a minimal wrapping container in the same file (SwiftUI has no built-in flow layout pre-`Layout`; use the `Layout` protocol, iOS 16+):

```swift
private struct FlexibleWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0, rowHeight: CGFloat = 0, totalHeight: CGFloat = 0, maxRowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth - spacing)
                rowWidth = 0; rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth - spacing)
        return CGSize(width: min(maxWidth, maxRowWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the Step 2 command. Expected: PASS (5 tests).

- [ ] **Step 5: Build to verify the view compiles**

Run: `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` — expect exit 0.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/CoreCoursesEditor.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/CoreCoursesLogicTests.swift
git commit -m "feat(profile): add CoreCoursesEditor chip component"
```

---

### Task A3: Move High School + add Core Courses into Academics tab

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/AcademicsSocialTab.swift`

**Interfaces:**
- Consumes: `CoreCoursesEditor` (A2), `PlayerDetails.coreCourses` (A1), existing `textRow(_:placeholder:keyPath:keyboardType:)` helper in this file.
- Produces: Academics tab content order — High School → Academics → Core Courses. Removes Social Media + Privacy cards (they move to Basics in A4).

- [ ] **Step 1: Edit the `body`**

Replace the `body`'s `VStack` contents so the cards are, in order: High School, Academics, Core Courses. Remove the `Social Media` and `Privacy` `cardSection` blocks entirely.

```swift
            VStack(spacing: 16) {
                cardSection(String(localized: "High School")) {
                    VStack(spacing: 0) {
                        textRow(String(localized: "High School"), keyPath: \.highSchool)
                        divider
                        textRow(String(localized: "City"), keyPath: \.schoolCity)
                        divider
                        textRow(String(localized: "State"), keyPath: \.schoolState)
                    }
                }

                cardSection(String(localized: "Academics")) {
                    VStack(spacing: 0) {
                        numericRow(String(localized: "GPA"), keyPath: \.gpa)
                        divider
                        intRow(String(localized: "SAT Score"), keyPath: \.satScore)
                        divider
                        intRow(String(localized: "ACT Score"), keyPath: \.actScore)
                    }
                }

                cardSection(String(localized: "Core Courses")) {
                    CoreCoursesEditor(
                        courses: Binding(
                            get: { viewModel.details.coreCourses ?? [] },
                            set: {
                                viewModel.details.coreCourses = $0.isEmpty ? nil : $0
                                viewModel.markChanged()
                            }
                        ),
                        isDisabled: viewModel.isReadOnly
                    )
                }
            }
```

Note: `textRow` here forces `.textInputAutocapitalization(.never)` + `.autocorrectionDisabled()` (it was built for handles). For High School/City/State that is acceptable but not ideal; if a State field should uppercase, leave as-is for now — parity with the simple text entry is fine and matches the moved-from behavior. (The Basics version used `.characters` for State; capturing that nuance is out of scope — City/State here use the shared handle-style row.)

- [ ] **Step 2: Build**

Run: `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` — expect exit 0.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/AcademicsSocialTab.swift
git commit -m "feat(profile): Academics tab now holds High School + Core Courses"
```

---

### Task A4: Move Contact + Privacy + Social into Basics tab

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/BasicsTab.swift`

**Interfaces:**
- Consumes: existing `viewModel.details` bindings, `markChanged()`, `isReadOnly`, and the `cardSection`/`divider` helpers already in BasicsTab.
- Produces: Basics content order — Profile Photo → Basic Information (grad year, primary sport only) → Contact → Social → College Preferences.

- [ ] **Step 1: Remove High School/City/State from `basicInfoCard`**

Current `basicInfoCard` has gradYear, primarySport, High School, City, State rows. Reduce to:

```swift
    private var basicInfoCard: some View {
        VStack(spacing: 0) {
            gradYearRow
            divider
            primarySportRow
        }
    }
```

- [ ] **Step 2: Add Contact + Social cards to `body`**

Insert between `Basic Information` and `College Preferences` sections:

```swift
                cardSection(String(localized: "Basic Information")) {
                    basicInfoCard
                }

                cardSection(String(localized: "Contact")) {
                    contactCard
                }

                cardSection(String(localized: "Social")) {
                    socialCard
                }

                cardSection(String(localized: "College Preferences")) {
                    collegePrefsCard
                }
```

- [ ] **Step 3: Add the `contactCard`, `socialCard`, and shared helpers**

```swift
    // MARK: - Contact Card

    @ViewBuilder
    private var contactCard: some View {
        VStack(spacing: 0) {
            handleRow(String(localized: "Phone"), placeholder: String(localized: "Phone"),
                      keyPath: \.phone, keyboardType: .phonePad)
            divider
            handleRow(String(localized: "Email"), placeholder: String(localized: "Email"),
                      keyPath: \.email, keyboardType: .emailAddress)
            divider
            toggleRow(String(localized: "Share phone with coaches"), keyPath: \.allowSharePhone)
            divider
            toggleRow(String(localized: "Share email with coaches"), keyPath: \.allowShareEmail)
        }
    }

    // MARK: - Social Card

    @ViewBuilder
    private var socialCard: some View {
        VStack(spacing: 0) {
            handleRow(String(localized: "Twitter"), placeholder: String(localized: "@username"), keyPath: \.twitterHandle)
            divider
            handleRow(String(localized: "Instagram"), placeholder: String(localized: "@username"), keyPath: \.instagramHandle)
            divider
            handleRow(String(localized: "TikTok"), placeholder: String(localized: "@username"), keyPath: \.tiktokHandle)
            divider
            handleRow(String(localized: "Facebook URL"), placeholder: String(localized: "https://..."), keyPath: \.facebookUrl, keyboardType: .URL)
        }
    }

    private func handleRow(
        _ label: String,
        placeholder: String = "",
        keyPath: WritableKeyPath<PlayerDetails, String?>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField(placeholder.isEmpty ? label : placeholder, text: Binding(
                get: { viewModel.details[keyPath: keyPath] ?? "" },
                set: {
                    viewModel.details[keyPath: keyPath] = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            ))
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func toggleRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, Bool?>) -> some View {
        Toggle(label, isOn: Binding(
            get: { viewModel.details[keyPath: keyPath] ?? false },
            set: {
                viewModel.details[keyPath: keyPath] = $0
                viewModel.markChanged()
            }
        ))
        .disabled(viewModel.isReadOnly)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` — expect exit 0.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/BasicsTab.swift
git commit -m "feat(profile): Basics tab now holds Contact, Privacy, and Social"
```

---

### Task A5: iOS full-suite regression + tab-title sanity

**Files:**
- Modify (only if a test references the moved fields' old tab): existing tests under `TheRecruitingCompassTests/Features/Preferences/`.

- [ ] **Step 1: Grep for tests asserting old placement**

Run: `grep -rn "Social Media\|Privacy\|High School\|schoolCity\|schoolState" TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences`
For any test asserting a field appears on a specific tab, update it to the new tab. If a test only checks the view builds/loads, no change.

- [ ] **Step 2: Run the Preferences test folder**

Run: `xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PlayerDetailsCodableTests -only-testing:TheRecruitingCompassTests/CoreCoursesLogicTests`
Expected: PASS. Then run any updated view tests by class name. Trust exit code.

- [ ] **Step 3: Commit any test updates**

```bash
git add -A
git commit -m "test(profile): align player-profile tests with new field homes"
```

---

## Phase B — Web

### Task B1: Rename the Academics tab label

**Files:**
- Modify: `pages/settings/player-details.vue:338`
- Test: `tests/unit/` (add/extend a tab-config test if one exists; otherwise assert in the Academics component test in B4)

**Interfaces:**
- Produces: tab `{ id: "academics", name: "Academics" }`.

- [ ] **Step 1: Change the label**

At line 338, change `name: "Academics & Social"` to `name: "Academics"`. Leave `id: "academics"` unchanged.

- [ ] **Step 2: Grep for hardcoded references**

Run: `grep -rn "Academics & Social\|Academics &amp; Social" .` (excluding node_modules). Update any snapshot/test copy.

- [ ] **Step 3: Commit**

```bash
git add pages/settings/player-details.vue
git commit -m "feat(profile): rename Academics & Social tab to Academics"
```

---

### Task B2: Move High School inputs Basics → Academics

**Files:**
- Modify: `components/Settings/PlayerDetailsBasicsTab.vue` (remove School Info block, lines ~67–122: High School Name / School City / School State, incl. `SharedHighSchoolSearchInput`)
- Modify: `components/Settings/PlayerDetailsAcademicsTab.vue` (add the block at top)
- Modify: `pages/settings/player-details.vue` (thread any props the block needs to the Academics tag; remove now-unused ones from Basics tag if they become unused)

**Interfaces:**
- Consumes: the block's inline `HighSchoolSelection` handler (currently in BasicsTab around line 84) mutates `form.high_school` / `form.school_city` / `form.school_state`; carry it verbatim into AcademicsTab. `SharedHighSchoolSearchInput` is a global/auto-imported component — no new import needed.
- Produces: High School section as the first card in AcademicsTab.

- [ ] **Step 1: Cut the School Info block from BasicsTab**

Remove the `<!-- School Info -->` block (High School Name label + `SharedHighSchoolSearchInput`, School City, School State) from `PlayerDetailsBasicsTab.vue`.

- [ ] **Step 2: Paste it as the first section in AcademicsTab**

Insert the block above the existing Academic Info section in `PlayerDetailsAcademicsTab.vue`, wrapped in the same card container style the other sections use (copy the wrapper classes from the adjacent Core Courses/Academic Info card). Keep the inline `@select` handler that sets `form.high_school`, `form.school_city`, `form.school_state`.

- [ ] **Step 3: Update tests to expect the failing state first**

In `tests/unit/` add/extend a component test:

```ts
// PlayerDetailsAcademicsTab renders High School inputs
expect(wrapper.find('[data-test="hs-name"]').exists()).toBe(true);
// PlayerDetailsBasicsTab no longer renders High School
expect(basicsWrapper.find('[data-test="hs-name"]').exists()).toBe(false);
```

Add matching `data-test` attributes to the moved inputs.

- [ ] **Step 4: Run the tests**

Run: `npx vitest run tests/unit/components/Settings` (adjust path to where the component tests live). Expected: PASS after the move.

- [ ] **Step 5: Commit**

```bash
git add components/Settings/PlayerDetailsBasicsTab.vue components/Settings/PlayerDetailsAcademicsTab.vue pages/settings/player-details.vue tests/
git commit -m "feat(profile): move High School inputs from Basics to Academics"
```

---

### Task B3: Consolidate Contact + Privacy into Basics; remove the Academics duplicate

**Files:**
- Modify: `components/Settings/PlayerDetailsBasicsTab.vue` (keep existing Recruiting Email/Phone block ~124–163; add the two privacy toggles beneath it)
- Modify: `components/Settings/PlayerDetailsAcademicsTab.vue` (remove the entire "Contact & Privacy" block — the duplicate `form.phone`/`form.email` inputs and both toggles, ~lines 153–225)

**Interfaces:**
- Consumes: `form.phone`, `form.email`, `form.allow_share_phone`, `form.allow_share_email`, `triggerSave`. All already available in BasicsTab.
- Produces: exactly one editing home for phone/email (Basics). Basics email/phone block relabeled "Contact"; toggles for share-phone/share-email added under it.

- [ ] **Step 1: Write the failing assertion**

Extend the component tests:

```ts
// Basics has the single contact home incl. privacy toggles
expect(basics.find('[data-test="share-phone"]').exists()).toBe(true);
expect(basics.find('[data-test="share-email"]').exists()).toBe(true);
// Academics no longer edits phone/email
expect(academics.find('[data-test="contact-phone"]').exists()).toBe(false);
```

- [ ] **Step 2: Remove the Academics Contact & Privacy block**

Delete the "Contact & Privacy" section (`h2` "Contact & Privacy" through the two toggle rows) from `PlayerDetailsAcademicsTab.vue`.

- [ ] **Step 3: Add the toggles under Basics' contact block**

In `PlayerDetailsBasicsTab.vue`, under the Recruiting Phone input, add the two toggle rows (copy the toggle markup that was in AcademicsTab, binding `form.allow_share_phone` / `form.allow_share_email`, calling `triggerSave` on change). Add `data-test="share-phone"` / `data-test="share-email"`. Optionally relabel the block comment to "Contact".

- [ ] **Step 4: Run the tests**

Run: `npx vitest run tests/unit/components/Settings`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add components/Settings/PlayerDetailsBasicsTab.vue components/Settings/PlayerDetailsAcademicsTab.vue tests/
git commit -m "feat(profile): single contact home in Basics; drop Academics phone/email dup"
```

---

### Task B4: Move Social Handles Academics → Basics + rethread props

**Files:**
- Modify: `components/Settings/PlayerDetailsAcademicsTab.vue` (remove Social Handles block ~115–150; remove now-unused `socialInputs` / `handleSocialBlur` from its `defineProps`)
- Modify: `components/Settings/PlayerDetailsBasicsTab.vue` (add Social Handles block; add `socialInputs` + `handleSocialBlur` to its `defineProps`)
- Modify: `pages/settings/player-details.vue` (move `:social-inputs` / `:handle-social-blur` bindings from the `<PlayerDetailsAcademicsTab>` tag to the `<PlayerDetailsBasicsTab>` tag)

**Interfaces:**
- Consumes from `player-details.vue`: `socialInputs`, `handleSocialBlur` (destructured from `usePlayerDetailsForm` at ~line 362–366).
- Produces: Basics renders the four social handle inputs via `v-for="social in socialInputs"`.

- [ ] **Step 1: Write the failing assertion**

```ts
// Basics renders social handles; Academics does not
expect(basics.find('[data-test="social-twitter_handle"]').exists()).toBe(true);
expect(academics.find('[data-test="social-twitter_handle"]').exists()).toBe(false);
```

Add `:data-test="`social-${social.key}`"` to the social input wrapper when moving it.

- [ ] **Step 2: Cut the Social Handles block from AcademicsTab; paste into BasicsTab**

Move the `<!-- Social Media -->` section (h2 "Social Handles" + the `v-for` inputs) into `PlayerDetailsBasicsTab.vue` (place after the Contact section, before College Preferences to match iOS order).

- [ ] **Step 3: Rethread props**

- In `PlayerDetailsBasicsTab.vue` `defineProps`, add:
  ```ts
  socialInputs: { key: keyof PlayerDetails; label: string; placeholder: string; prefix?: string }[];
  handleSocialBlur: (key: string, value: string) => void;
  ```
  (Match the exact shape currently declared in AcademicsTab's `defineProps`.)
- In `PlayerDetailsAcademicsTab.vue` `defineProps`, remove `socialInputs` and `handleSocialBlur`.
- In `pages/settings/player-details.vue`, move `:social-inputs="socialInputs"` and `:handle-social-blur="handleSocialBlur"` from the `<PlayerDetailsAcademicsTab .../>` tag to the `<PlayerDetailsBasicsTab .../>` tag.

- [ ] **Step 4: Run the tests + typecheck**

Run: `npx vitest run tests/unit/components/Settings` then `npx nuxi typecheck` (or the repo's typecheck script). Expected: PASS, no type errors.

- [ ] **Step 5: Commit**

```bash
git add components/Settings/PlayerDetailsBasicsTab.vue components/Settings/PlayerDetailsAcademicsTab.vue pages/settings/player-details.vue tests/
git commit -m "feat(profile): move Social Handles from Academics to Basics"
```

---

### Task B5: Web regression + manual parity check

- [ ] **Step 1: Full unit run**

Run: `npx vitest run` (or repo test script). Expected: PASS. Fix any snapshot referencing old placement.

- [ ] **Step 2: Manual smoke (dev server)**

Run the app, open Settings → Player Details. Verify: Basics shows grad/sport, Contact (phone/email + 2 toggles), Social (4), College Preferences; Academics shows High School (name/city/state), GPA/SAT/ACT, Core Courses; phone/email editable in exactly one place; a value typed in Basics persists (triggerSave) and reloads.

- [ ] **Step 3: Commit any snapshot fixes**

```bash
git add -A
git commit -m "test(profile): update web snapshots for tab reorg"
```

---

## Self-Review

**Spec coverage:**
- iOS missing `core_courses` → A1, A2, A3. ✓
- iOS missing phone/email inputs → A4 (Contact card). ✓
- Contact+Privacy → Basics → A4 (iOS), B3 (web). ✓
- Social → Basics → A4 (iOS), B4 (web). ✓
- High School → Academics → A3 (iOS), B2 (web). ✓
- Web dup phone/email collapse → B3. ✓
- Rename web tab → B1. ✓
- Campus/cost stay, Athletics/History/IDs untouched → not modified by any task. ✓
- No migration → no DB task. ✓

**Placeholder scan:** No TBD/TODO. Core-courses rules are concrete (20/60/trim/dedupe). Web move tasks reference exact files, line ranges, prop names, and `data-test` hooks rather than reproducing entire Vue DOM blocks (the blocks are moved verbatim, not rewritten).

**Type consistency:** `coreCourses: [String]?` (A1) used by `CoreCoursesEditor(courses: Binding<[String]>...)` (A2) via `?? []` bridge (A3). `normalizedToAdd(_:existing:)` signature consistent A2↔tests. Web `socialInputs`/`handleSocialBlur` prop shapes moved intact B4.

**Open risk flagged in A3:** the shared iOS `textRow` forces `.never` autocapitalization; State field loses the `.characters` uppercase the Basics version had. Documented as an accepted minor divergence, not a silent change.
