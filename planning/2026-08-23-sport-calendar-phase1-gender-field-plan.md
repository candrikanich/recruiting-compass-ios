# Sport Calendar — Phase 1: Gender Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional self-reported `gender` profile field (male|female|other|prefer_not_to_say) to the athlete profile on web and iOS, so the per-sport recruiting calendar (Phase 2+) can auto-pick men's/women's calendars.

**Architecture:** `gender` is stored in the `user_preferences.player_details` JSON blob (JSONB, schema-less → **no DB migration**), mirroring the existing blob-only optional enums `campus_size_preference` / `cost_sensitivity`. It is edited on the profile "Basics" tab and collected (optionally) at onboarding. Family-shared parent-edit is already free on both platforms. Byte-identical enum string values across web + iOS.

**Tech Stack:** Web = Nuxt 3 / Vue 3 / TypeScript / Zod / Vitest. iOS = SwiftUI / Swift / XCTest.

**Spec:** `planning/2026-08-23-sport-recruiting-calendar-design.md` (§4 Gender field). Read it alongside this plan.

## Global Constraints

- **Enum values (byte-identical both platforms):** exactly `male`, `female`, `other`, `prefer_not_to_say`. iOS Swift enum needs an explicit rawValue for `preferNotToSay = "prefer_not_to_say"`.
- **Storage:** `player_details` JSON blob only. **No DB migration, no `users` column, no `types/database.ts` change.**
- **Optional/nullable everywhere:** never required to use the app; `prefer_not_to_say` is a first-class value, not an error.
- **Parity discipline:** same key string (`gender`), same option values, same order (male, female, other, prefer_not_to_say). Only display labels localize.
- **Branches (create via superpowers:using-git-worktrees at execution):** web → new `feat/sport-recruiting-calendar` off `origin/develop`; iOS → new `feat/sport-recruiting-calendar` off `origin/main`. Do NOT reuse `feat/deferred-cleanup` (that branch is the unrelated deferred-cleanup work). Copy gitignored `Release.xcconfig` into the iOS worktree.
- **Repo roots:** web `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web`; iOS source is double-nested under `TheRecruitingCompass/TheRecruitingCompass/`, xcodebuild runs from `TheRecruitingCompass/`.
- **Web push:** pre-push hook crashes (Abort trap 6) — push with `--no-verify` after running type-check + lint directly.

---

## File Structure

**Web (`recruiting-compass-web`):**
- Modify `types/models.ts` — add `gender` to `PlayerDetails` interface.
- Modify `utils/validation/schemas.ts` — add `gender` to `playerDetailsSchema`.
- Modify `utils/preferenceValidation.ts` — add `gender` to `validatePlayerDetails()` runtime guard.
- Modify `composables/usePlayerDetailsForm.ts` — `GENDER_OPTIONS` const + form default + save payload.
- Modify `components/Settings/PlayerDetailsBasicsTab.vue` — gender `<select>` + prop.
- Modify `pages/onboarding/index.vue` — optional gender `<select>`.
- Modify `server/api/family/player-details.post.ts` — accept `gender` in parent pre-fill.
- Tests: `tests/unit/validation/schemas.test.ts`.

**iOS (`recruiting-compass-ios`):**
- Create `TheRecruitingCompass/TheRecruitingCompass/Core/Models/Gender.swift` — `Gender` enum.
- Modify `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Models/PlayerDetails.swift` — `var gender` + CodingKey.
- Modify `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/BasicsTab.swift` — gender Picker.
- Modify `TheRecruitingCompass/TheRecruitingCompass/Features/Onboarding/Views/OnboardingView.swift` + `.../Onboarding/Utilities/OnboardingConstants.swift` — optional gender step.
- Tests: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/PlayerDetailsCodableTests.swift`.

---

## WEB TASKS

### Task 1: Gender in PlayerDetails type + validators

**Files:**
- Modify: `types/models.ts:361-446` (PlayerDetails interface)
- Modify: `utils/validation/schemas.ts:294-347` (playerDetailsSchema)
- Modify: `utils/preferenceValidation.ts:87-140` (validatePlayerDetails)
- Test: `tests/unit/validation/schemas.test.ts`

**Interfaces:**
- Produces: `PlayerDetails.gender?: "male" | "female" | "other" | "prefer_not_to_say"`; `playerDetailsSchema` accepts/rejects the enum; `validatePlayerDetails()` coerces `gender` via `toOption`.

- [ ] **Step 1: Write the failing test** — append to the `playerDetailsSchema` describe block in `tests/unit/validation/schemas.test.ts`:

```ts
it("accepts valid gender values", () => {
  for (const g of ["male", "female", "other", "prefer_not_to_say"]) {
    expect(playerDetailsSchema.safeParse({ gender: g }).success).toBe(true);
  }
});
it("accepts null/absent gender", () => {
  expect(playerDetailsSchema.safeParse({ gender: null }).success).toBe(true);
  expect(playerDetailsSchema.safeParse({}).success).toBe(true);
});
it("rejects unknown gender", () => {
  expect(playerDetailsSchema.safeParse({ gender: "M" }).success).toBe(false);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web && npx vitest run tests/unit/validation/schemas.test.ts -t gender`
Expected: FAIL (`gender` currently stripped/undefined; `"M"` passes because unknown keys are ignored).

- [ ] **Step 3: Add the field to the type** — in `types/models.ts` `PlayerDetails` (near the other enum fields ~line 372):

```ts
gender?: "male" | "female" | "other" | "prefer_not_to_say";
```

- [ ] **Step 4: Add to Zod schema** — in `utils/validation/schemas.ts` `playerDetailsSchema` (mirror the `bats` line at :298):

```ts
gender: z.enum(["male", "female", "other", "prefer_not_to_say"]).nullable().optional(),
```

- [ ] **Step 5: Add to runtime guard** — in `utils/preferenceValidation.ts` `validatePlayerDetails()` (mirror the `bats` `toOption` at :111):

```ts
gender: toOption<"male" | "female" | "other" | "prefer_not_to_say">(
  obj.gender,
  ["male", "female", "other", "prefer_not_to_say"],
),
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web && npx vitest run tests/unit/validation/schemas.test.ts -t gender`
Expected: PASS (3 assertions).

- [ ] **Step 7: Type-check**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web && npm run -s type-check 2>&1 | grep -E "error TS" || echo NO_TS_ERRORS`
Expected: `NO_TS_ERRORS`.

- [ ] **Step 8: Commit**

```bash
git add types/models.ts utils/validation/schemas.ts utils/preferenceValidation.ts tests/unit/validation/schemas.test.ts
git commit -m "feat(profile): add gender to PlayerDetails type + validators"
```

### Task 2: Gender on the Basics tab (form + UI)

**Files:**
- Modify: `composables/usePlayerDetailsForm.ts:48-107,158-167` (GENDER_OPTIONS const, form default, save payload)
- Modify: `components/Settings/PlayerDetailsBasicsTab.vue:26-40,277-295` (select + prop)

**Interfaces:**
- Consumes: `PlayerDetails.gender` (Task 1).
- Produces: `GENDER_OPTIONS` exported from `usePlayerDetailsForm.ts`; `form.gender` two-way bound; gender in the `setPlayerDetails` payload.

- [ ] **Step 1: Add the options const** — in `composables/usePlayerDetailsForm.ts` next to `CAMPUS_SIZE_OPTIONS` (:48):

```ts
const GENDER_OPTIONS = [
  { value: "male", label: "Male" },
  { value: "female", label: "Female" },
  { value: "other", label: "Other" },
  { value: "prefer_not_to_say", label: "Prefer not to say" },
] as const;
```

- [ ] **Step 2: Add form default** — in the form defaults block (`:63-107`), add:

```ts
gender: undefined,
```

- [ ] **Step 3: Include gender in the save payload** — in the `onSave` `detailsToSave` builder (`:158-167`), add:

```ts
gender: form.gender,
```

- [ ] **Step 4: Return GENDER_OPTIONS** — ensure the composable returns `GENDER_OPTIONS` (alongside `CAMPUS_SIZE_OPTIONS`) so the page can pass it as a prop.

- [ ] **Step 5: Add the prop + select to the Basics tab** — in `components/Settings/PlayerDetailsBasicsTab.vue`, add a `genderOptions` prop (props block :277-295) and, after the Graduation Year `<select>` (:26-40), add:

```html
<div>
  <label class="block text-sm font-medium mb-1">Gender <span class="text-gray-400">(optional)</span></label>
  <select v-model="form.gender" :disabled="isParentRole" @change="triggerSave"
          class="w-full rounded border px-3 py-2">
    <option :value="undefined">Prefer not to answer</option>
    <option v-for="opt in genderOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
  </select>
</div>
```

- [ ] **Step 6: Pass the prop from the host page** — in `pages/settings/player-details.vue` where `PlayerDetailsBasicsTab` is rendered (:125), add `:gender-options="GENDER_OPTIONS"` (destructure `GENDER_OPTIONS` from `usePlayerDetailsForm()` at :392-421).

- [ ] **Step 7: Type-check + build the component**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web && npm run -s type-check 2>&1 | grep -E "error TS" || echo NO_TS_ERRORS`
Expected: `NO_TS_ERRORS`.

- [ ] **Step 8: Commit**

```bash
git add composables/usePlayerDetailsForm.ts components/Settings/PlayerDetailsBasicsTab.vue pages/settings/player-details.vue
git commit -m "feat(profile): gender selector on player-details Basics tab"
```

### Task 3: Optional gender at onboarding

**Files:**
- Modify: `pages/onboarding/index.vue:65-111` (gender select)
- Modify: `server/api/family/player-details.post.ts:11,34` (parent pre-fill accepts gender)

**Interfaces:**
- Consumes: `PlayerDetails.gender` (Task 1), `setPlayerDetails` (existing).
- Produces: onboarding writes `gender` into player_details; parent pre-fill carries `gender`.

- [ ] **Step 1: Add the onboarding select** — in `pages/onboarding/index.vue`, after the primary_sport block (:86), mirror the graduation-year `<select>` (:65), bound to `onboardingData.gender`, labeled optional (no `*`):

```html
<select id="onboarding-gender" v-model="onboardingData.gender" class="...">
  <option :value="undefined">Gender (optional)</option>
  <option value="male">Male</option>
  <option value="female">Female</option>
  <option value="other">Other</option>
  <option value="prefer_not_to_say">Prefer not to say</option>
</select>
```

- [ ] **Step 2: Persist it** — ensure the onboarding submit includes gender in its `setPlayerDetails({ ... })` call (mirror `select-sport.vue:95`), e.g. `gender: onboardingData.gender`.

- [ ] **Step 3: Parent pre-fill** — in `server/api/family/player-details.post.ts`, add `gender` to the destructure (:11) and to the `pending_player_details` write (:34).

- [ ] **Step 4: Type-check**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web && npm run -s type-check 2>&1 | grep -E "error TS" || echo NO_TS_ERRORS`
Expected: `NO_TS_ERRORS`.

- [ ] **Step 5: Run the full validation test file (regression)**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web && npx vitest run tests/unit/validation/schemas.test.ts`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add pages/onboarding/index.vue server/api/family/player-details.post.ts
git commit -m "feat(onboarding): optional gender step + parent pre-fill"
```

---

## iOS TASKS

### Task 4: Gender enum + PlayerDetails.gender + Codable test

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Models/Gender.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Models/PlayerDetails.swift` (var ~L90-91 area, CodingKeys ~L205-277)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/PlayerDetailsCodableTests.swift`

**Interfaces:**
- Produces: `enum Gender: String` with cases `.male/.female/.other/.preferNotToSay` (rawValues byte-identical to web); `PlayerDetails.gender: String?` decoded from `"gender"`.

- [ ] **Step 1: Write the failing test** — add to `PlayerDetailsCodableTests`:

```swift
func testGenderDecodesAndReencodesSnakeCase() throws {
    let json = #"{"gender":"prefer_not_to_say"}"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(PlayerDetails.self, from: json)
    XCTAssertEqual(decoded.gender, "prefer_not_to_say")
    let data = try JSONEncoder().encode(decoded)
    let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    XCTAssertEqual(obj["gender"] as? String, "prefer_not_to_say")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PlayerDetailsCodableTests/testGenderDecodesAndReencodesSnakeCase`
Expected: FAIL (no `gender` member).

- [ ] **Step 3: Create the Gender enum** — `Core/Models/Gender.swift` (mirror `UserRole.swift`):

```swift
import Foundation

enum Gender: String, Codable, CaseIterable, Sendable {
    case male
    case female
    case other
    case preferNotToSay = "prefer_not_to_say"

    var displayName: String {
        switch self {
        case .male: return String(localized: "Male")
        case .female: return String(localized: "Female")
        case .other: return String(localized: "Other")
        case .preferNotToSay: return String(localized: "Prefer not to say")
        }
    }
}
```

- [ ] **Step 4: Add the field + CodingKey to PlayerDetails** — in `PlayerDetails.swift`, add near the other optional-String profile fields (~L90):

```swift
var gender: String?
```

and in `CodingKeys` (~L259):

```swift
case gender
```

(`gender` matches its snake_case key exactly, so no `= "..."` needed.)

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PlayerDetailsCodableTests`
Expected: PASS (trust exit code + counts, not a grep).

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Models/Gender.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Models/PlayerDetails.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/PlayerDetailsCodableTests.swift
git commit -m "feat(profile): add Gender enum + PlayerDetails.gender (iOS)"
```

### Task 5: Gender Picker on Basics tab + onboarding

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/BasicsTab.swift:236-342` (Picker row)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Onboarding/Views/OnboardingView.swift:140-197` + `.../Onboarding/Utilities/OnboardingConstants.swift` (optional step)

**Interfaces:**
- Consumes: `PlayerDetails.gender` (Task 4), `Gender` enum. Persistence is free (blob round-trip via `saveDetails()`); parent-edit free (`isReadOnly=false`).

- [ ] **Step 1: Add a gender menu Picker to the Basics tab** — in `BasicsTab.swift`, in `collegePrefsCard`/basics area, mirror `primarySportRow` (:320-342) menu-Picker `Binding{get/set}` + `viewModel.markChanged()` shape, iterating `Gender.allCases`:

```swift
private var genderRow: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(String(localized: "Gender (optional)")).font(.subheadline.weight(.medium))
        Picker(String(localized: "Gender"), selection: Binding(
            get: { viewModel.details.gender ?? "" },
            set: { viewModel.details.gender = $0.isEmpty ? nil : $0; viewModel.markChanged() }
        )) {
            Text(String(localized: "Prefer not to answer")).tag("")
            ForEach(Gender.allCases, id: \.rawValue) { g in
                Text(g.displayName).tag(g.rawValue)
            }
        }.pickerStyle(.menu)
    }
}
```

Reference `genderRow` in the Basics card body next to the campus/cost rows.

- [ ] **Step 2: Build to verify the tab compiles**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: exit 0, no new errors.

- [ ] **Step 3: Add optional onboarding step** — in `OnboardingConstants.swift` add nothing new (use `Gender.allCases`); in `OnboardingBasicInfoStep` (`OnboardingView.swift:140-197`) add a `.menu` Picker mirroring the Primary Sport block (:160-169), bound to `viewModel.gender` (add an optional `var gender: String?` to `OnboardingViewModel` and include it in its player-details submit). Label optional (no `*`).

- [ ] **Step 4: Build**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: exit 0.

- [ ] **Step 5: Run the Preferences test suite (regression)**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PlayerDetailsCodableTests -only-testing:TheRecruitingCompassTests/PlayerDetailsViewModelTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/BasicsTab.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Onboarding/
git commit -m "feat(profile): gender Picker on Basics tab + optional onboarding step (iOS)"
```

---

## Parity Checkpoint (after all tasks)

- [ ] Enum values identical both platforms: `male`, `female`, `other`, `prefer_not_to_say` — grep both repos, diff the option lists.
- [ ] Web: `npm run -s type-check` clean; `npx vitest run tests/unit/validation/schemas.test.ts` green.
- [ ] iOS: `xcodebuild build` clean; `PlayerDetailsCodableTests` green.
- [ ] Manual: set gender on web Basics tab → reload → persists; set on iOS → round-trips. Parent editing athlete's profile can set gender on both.
- [ ] Open PRs: web → `develop` (push `--no-verify`), iOS → `main`. Note in each PR that this is Phase 1 of the sport-recruiting-calendar effort (spec linked).

---

## Self-Review Notes (author)

- **Spec coverage:** §4 Gender field fully covered (type, validators, UI, onboarding, parity, privacy). DB migration intentionally omitted per the spec's blob-only decision.
- **Deferred to later phases (not Phase 1):** calendar data (P2), resolver using gender + M/W toggle fallback (P2), server rule-engine rewire (P3), iOS calendar widget (P4), refresh job (P5). The M/W self-select toggle for null/other gender is a *calendar-view* concern → built in P2, not here.
- **Assumption to verify at execution:** `OnboardingViewModel` has no `gender` property yet (Task 5 Step 3 adds it). If onboarding is deemed out-of-scope by the implementer, Tasks 1/2/4/5-step1-2 still deliver a complete, testable field; drop Task 3 + Task 5 Step 3 without breaking anything.
