# iOS Spec — Inbound Draft Review: Coach Email Prefill + School-Creation Entry Point

> **Prepared:** 2026-09-09
> **Web branch:** `develop` (PR #737, closes issue #675)
> **iOS issue:** #125
> **Purpose:** Close two gaps in the iOS inbound-draft review form (shipped in iOS PR #116 / issue #113): the add-coach sheet opens blank even when the draft already knows the sender's name/email, and there's no way to create a missing school without abandoning the draft in progress.

---

## Existing iOS Files (Step 0 parity check — classification: PARTIAL)

The draft review flow itself is **fully shipped** (iOS PR #116, memory: "Inbound-draft confirm → review form SHIPPED"). This spec only covers the two specific gaps from issue #675/#125, not the review flow as a whole.

- `Features/Interactions/Views/AddInteractionView.swift` — the review form (`draftToConfirm` param). School section is a plain `Picker` over `viewModel.schools` with no "create new" option. Coach section already has an "+ Add new coach" picker row wired to `viewModel.showAddCoachSheet`.
- `Features/Interactions/ViewModels/AddInteractionViewModel.swift` — `prefillFromDraft(_:)` prefills type/direction/subject/content/occurredAt/coachId/schoolId but never touches `newCoachForm`. `createNewCoach()` hardcodes `email: nil` in the `CoachCreateRequest`.
- `Shared/Components/Forms/AddCoachSheet.swift` — inline sheet with First Name / Last Name / Role. **No email field.**
- `Features/Interactions/Models/NewCoachFormState.swift` — `firstName`, `lastName`, `role` only. **No email field.**
- `Features/InboundDrafts/Models/InboundEmailDraft.swift` — already has `senderName: String?` and `senderEmail: String?` (used today only for `displaySenderName` on the list card). This is the source data for both fixes below.
- `Features/Schools/Presentation/Views/AddSchoolView.swift` / `AddSchoolViewModel.swift` — the full school-creation flow (autocomplete, NCAA lookup, duplicate detection). Tightly coupled to a `NavigationPath` binding: on success it does `navigationPath.append(SchoolDestination.detail(newSchool.id))`. **Cannot be reused as-is** inside the review form's sheet without a new completion path — see design note below.
- `Features/Coaches/Models/CoachCreateRequest.swift` — already has an `email: String?` field; `AddInteractionViewModel.createNewCoach()` just always passes `nil` today.

**Key structural difference from web, worth calling out:** web's `InteractionForm.vue` is a page-level component, so creating a school means a full page navigation to `/schools/new` and back, round-tripping state via `returnTo`/`prefillWebsite`/`schoolId` query params (and PR #737 had to add a `draftLoaded` readiness gate to stop that round trip from clobbering the in-progress form). On iOS, `AddInteractionView` is always presented as a `.sheet` with its own `NavigationStack` (see `InboundDraftsView.swift`, `CoachDetailView.swift`, `SchoolDetailView.swift`, `ActionItemSheets.swift`) or pushed inside an existing stack (`InteractionsListView.swift`). **There is no analogous round-trip risk on iOS** — a new self-contained "Add School" sheet (mirroring the existing `AddCoachSheet` pattern) keeps the review form's `@Observable` view model alive the whole time; no state serialization across a navigation boundary is needed. Build it as a sheet, not a pushed screen, and don't try to port the query-param mechanism.

---

## Feature Overview

When reviewing a forwarded coach email in "Review Coach Email" (the confirm-draft form):

1. **Coach side:** tapping "+ Add new coach" opens a sheet that is now prefilled with the sender's name (split into first/last, best-effort) and email, instead of opening blank. The user can still edit or clear any field before saving.
2. **School side:** if the sender's school isn't in the picker, a new "School not listed? Add it" affordance next to the School picker opens a self-contained add-school sheet (prefilled website from the sender's email domain where derivable). Saving creates the school, selects it in the review form's School picker, and returns straight to the review form — the in-progress draft review (subject/body/type/direction edits) is untouched.

No new tables, no new endpoints — pure client wiring on top of existing `createCoach`/`createSchool` calls, matching web PR #737 exactly in scope.

---

## What iOS Needs to Build

### Screens / Components

| Component | Purpose | Entry Point |
|---|---|---|
| `AddCoachSheet` (existing, extended) | Add-coach form gains an Email field | "+ Add new coach" row in the review form's Coach picker (unchanged entry point) |
| `AddSchoolSheet` (new) | Self-contained add-school form, reusing `AddSchoolViewModel` + existing form sections, with a completion closure instead of `NavigationPath` push | New "School not listed? Add it" button/link in the review form's School section |

### Section / Component Breakdown

**Coach section (`AddInteractionView.coachSection`) — no visual change to the picker itself.**
- The "+ Add new coach" row still sets `showAddCoachSheet = true`.
- Behavior change: the sheet now opens pre-populated when reviewing a draft.

**`AddCoachSheet` — new Email field**
- Display: new `TextField("Email (Optional)", text: $email)` between Last Name and Role, `.keyboardType(.emailAddress)`, `.textContentType(.emailAddress)`, `.textInputAutocapitalization(.never)`, `.autocorrectionDisabled()`.
- Interaction: freely editable; not required.
- States: no new validation state — `isValid` stays based on first/last name only (email is optional on both platforms).

**School section (`AddInteractionView.schoolSection`) — new entry point**
- Display: a `Button` or `Link`-styled row below the `Picker`, reading "School not listed? Add it" (mirrors web's `NuxtLink` copy exactly), shown only while reviewing a draft (`draftToConfirm != nil`) OR always-visible — **recommend always-visible** (manual logging benefits from this too, and iOS has no `draftReturnTo`-gated visibility constraint like web does; confirm with the user before implementing web-only-gated visibility if strict web parity on visibility is preferred instead).
- Interaction: tapping opens `AddSchoolSheet` as a `.sheet`.
- States: no loading/error state at this level — `AddSchoolSheet` owns its own.

**`AddSchoolSheet` (new)**
- Display: reuse `AddSchoolAutocompleteToggleSection`, `AddSchoolFormSection`, `AddSchoolActionsSection`, and `SchoolDuplicateDialog` — the same subviews `AddSchoolView` already composes — inside its own `NavigationStack` + `Form`.
- Owns its own `AddSchoolViewModel` (via `SchoolsFactory.makeAddViewModel(schoolsService:familyUnitId:userId:)`), seeded with an optional prefill website.
- On successful `viewModel.submitSchool()` (non-nil `School` returned, no duplicate dialog pending): call `onSchoolCreated(newSchool)` and dismiss. **Do not** navigate to `SchoolDestination.detail` — that's `AddSchoolView`'s behavior, not this sheet's.
- Duplicate detection: same as `AddSchoolView` — show `SchoolDuplicateDialog` when `viewModel.showDuplicateDialog` is true, respecting the user's "use existing" vs "create anyway" choice before completing.
- Cancel: dismiss with no callback.

### Prefill Sourcing (parity with web's `splitSenderName` / domain-from-email)

- **Coach prefill**, in `AddInteractionViewModel.prefillFromDraft(_:)`:
  - `newCoachForm.firstName` / `newCoachForm.lastName` — best-effort split of `draft.senderName` on whitespace: first token → first name, remaining tokens joined → last name; empty/nil → both blank. (Same rule as web's `splitSenderName` in `AddCoachModal.vue` — port it as a small pure function, e.g. `NewCoachFormState.prefill(fromSenderName:)` or a free function next to the struct.)
  - `newCoachForm.email` — `draft.senderEmail?.trimmingCharacters(in: .whitespaces) ?? ""`.
  - Only prefill when `draftToConfirm != nil`; manual "Log Interaction" (`draftToConfirm == nil`) leaves `newCoachForm` at its default blank state — matches web's "opens empty when no sender info is provided" test case.
- **School prefill website**, passed into `AddSchoolSheet`'s init:
  - Derive from `draft.senderEmail`: split on `"@"`, take the **last** segment (guards a malformed multi-`@` address the same way web's `segments[segments.length - 1]` does), and only use it if non-empty. Build `"https://\(domain)"`.
  - No `@` at all → no prefill (nil), same as web's `domain` ending up empty.

### `CoachCreateRequest` wiring

`AddInteractionViewModel.createNewCoach()` currently does:
```swift
email: nil,
```
Change to:
```swift
email: newCoachForm.trimmedEmail.isEmpty ? nil : newCoachForm.trimmedEmail,
```
(Add a `trimmedEmail` computed property to `NewCoachFormState`, mirroring `trimmedFirstName`/`trimmedLastName`.)

---

## Data Model Changes (Swift)

```swift
// Features/Interactions/Models/NewCoachFormState.swift
struct NewCoachFormState {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""        // NEW
    var role: CoachRole = .assistant

    var trimmedEmail: String {    // NEW
        email.trimmingCharacters(in: .whitespaces)
    }

    mutating func reset() {
        firstName = ""
        lastName = ""
        email = ""                 // NEW
        role = .assistant
    }
    // isValid / trimmedFirstName / trimmedLastName / fullName unchanged
}
```

No changes needed to `InboundEmailDraft` (already has `senderName`/`senderEmail`), `CoachCreateRequest` (already has `email: String?`), or `SchoolCreateRequest` (already has `website: String?`).

---

## API Endpoints to Call

None new. Both flows call existing endpoints already wired on iOS:
- Coach creation: whatever `InteractionsManaging.createCoach(_:)` already calls (unchanged request shape, just a non-nil `email` now flows through when present).
- School creation: whatever `SchoolsManaging`/`AddSchoolViewModel.submitSchool()` already calls (unchanged request shape, just a `website` prefill now flows through when derivable).

---

## Business Rules to Enforce Client-Side

- Coach email is **optional** on save — do not add a required-field error for it (matches web: `Email (Optional)` label, no validation).
- Coach prefill only happens when reviewing a draft (`draftToConfirm != nil`); never prefill for a manually-started "Log Interaction".
- School website prefill requires the sender email to contain `@` with a non-empty trailing segment; otherwise leave the website field to its normal default (empty / autocomplete-driven).
- Creating a school from inside the review sheet must **select it** in the review form's `formState.schoolId` and must **not** discard any other field the user has already edited (subject, content, type, direction, sentiment, coach selection) — this is the iOS equivalent of the exact regression web's `draftLoaded` fix addressed, guaranteed here structurally by keeping the same `AddInteractionViewModel` instance alive underneath the child sheet rather than tearing down and reloading the form.
- Same trimming rules as the rest of the form: empty-after-trim strings become `nil`/blank, never sent as whitespace-only values.

---

## Excluded Items (No iOS Work Needed)

- **NCES-domain validation for auto-creating schools** — web's issue #675 explicitly dropped this ask after investigation (no domain-keyed dataset exists). School and coach creation stay explicit, user-initiated form submits on both platforms — nothing to build here.
- **DB migrations / RLS** — none in web PR #737; N/A here too.
- **`returnTo` / `prefillWebsite` / `schoolId` query-param mechanism** — web-only plumbing needed because web's form lives at a routable URL. iOS's sheet-based presentation makes this whole mechanism unnecessary (see structural note above).
- **The `draftLoaded` readiness-gate fix** — that fixed a bug specific to web's `initialData` prop being snapshotted once at `<script setup>` time before an async `onMounted` draft fetch resolved. iOS's `AddInteractionViewModel.loadFormData()` already awaits schools/coaches *and* calls `prefillFromDraft` before the form ever renders (`isLoading` gates the whole `Form` body) — this class of bug cannot occur on iOS as currently structured. No equivalent fix needed.

---

## Dependencies

- `Features/Schools/DI/SchoolsFactory.makeAddViewModel(schoolsService:familyUnitId:userId:)` — must already exist and be usable outside `AddSchoolView`'s own init path (confirm it takes no `NavigationPath` dependency itself — from the read source, the `NavigationPath` binding lives on `AddSchoolView`, not the factory or view model, so this should already be safe to reuse).
- `Features/Schools/Presentation/Components/` — whatever files define `AddSchoolAutocompleteToggleSection`, `AddSchoolFormSection`, `AddSchoolActionsSection`, `SchoolDuplicateDialog` (confirm exact file paths during implementation; not enumerated above since Step 0 search focused on the interaction/coach side).

---

## Notes for iOS Claude

- Keep `AddCoachSheet` a dumb view (bindings + closures only, matching its current style) — do the prefill logic in the view model (`prefillFromDraft`), not the view, same as every other field on this form.
- Name the new sheet `AddSchoolSheet` (not `AddSchoolView`) to make clear at a glance it's the review-form-local variant, distinct from the full-navigation `AddSchoolView` used from `SchoolsListView`.
- Watch for `AddSchoolViewModel`'s duplicate-detection flow (`AddSchoolViewModel+DuplicateDetection.swift`) — `submitSchool()` returns `nil` and sets `showDuplicateDialog = true` on a detected duplicate rather than failing outright. `AddSchoolSheet` must replicate `AddSchoolView`'s duplicate-dialog handling (present `SchoolDuplicateDialog`, let the user choose, then proceed) rather than treating a `nil` return as a hard failure.
- Double-check whether `AddSchoolViewModel`'s NCAA/College-Scorecard autocomplete step needs any changes to accept a prefilled website that arrived independently of a selected college — the prefill should seed `formState.website` directly (like web's `initialData.website = selectedCollege?.website || prefillWebsite || ''`), not go through the autocomplete/scorecard pipeline.
- This is a small, additive diff — no existing test should need behavior changes other than `NewCoachFormStateTests` / `AddInteractionViewModelTests` gaining new assertions for the prefill and `email` passthrough.

---

## Test Checklist

1. Open "Review Coach Email" for a draft with a `senderName` of "Mark Royer" and `senderEmail` of "mroyer@osu.edu" that has no `matchedCoachId`. Tap "+ Add new coach" — First Name shows "Mark", Last Name shows "Royer", Email shows "mroyer@osu.edu". Save — the created coach has that email.
2. Same draft, but edit the prefilled email before saving — the edited value is what gets sent, not the original prefill.
3. Open "Log Interaction" manually (not from a draft) — tap "+ Add new coach" — all fields are blank, exactly like today.
4. A draft with `senderName` of a single word (e.g. "Coach") — First Name shows "Coach", Last Name is blank; saving does not error (last name isn't force-required against draft data — user must still type one to satisfy the existing `isValid` check, matching today's manual-entry requirement).
5. Open "Review Coach Email" for a draft with no matched school. Tap "School not listed? Add it" — the add-school sheet opens with website prefilled to `https://osu.edu` (from `mroyer@osu.edu`). Complete the form and save — the new school is selected in the review form's School picker, and the subject/body/type/direction the reviewer had already edited are still present, unchanged.
6. Same as #5, but the sender email has no `@` (or is nil) — the add-school sheet opens with an empty website field, no crash.
7. From the add-school sheet, trigger a duplicate-school match (same name/location as an existing school) — the duplicate dialog appears; choosing "use existing" selects that existing school back in the review form (not a newly created duplicate); choosing "create anyway" creates and selects a new school.
8. Cancel out of the add-school sheet without saving — the review form is unchanged, still showing its in-progress edits, with no school newly selected.
