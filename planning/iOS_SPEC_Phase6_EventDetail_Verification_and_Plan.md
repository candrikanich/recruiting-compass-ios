# iOS Event Detail Spec: Verification & Completion Plan

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase6_EventDetail.md`  
**Date:** 2026-02-18  
**Status:** Spec largely implemented; gaps identified below with completion plan.

---

## 1. Verification Summary

### 1.1 Implemented (Spec Compliant)

| Spec requirement | Implementation | Location |
|------------------|----------------|----------|
| View event details (dates, location, cost, status, description) | ✅ | `EventHeaderSection`, `EventLocationSection`, `EventDetailsSection`, `EventPerformanceSection` |
| Edit event (modal/sheet, pre-filled) | ✅ | `EditEventSheet`, `openEditForm()`, `updateEvent()`, `EditEventData.from(event)` |
| Delete event with confirmation | ✅ | `confirmationDialog`, `confirmDelete()`, `deleteEvent()`, `shouldDismiss` → dismiss |
| Mark as attended → quick interaction modal | ✅ | `markAsAttended()`, then `showQuickLogSheet = true`; toolbar "Mark as attended" |
| Get directions (Maps) | ✅ | `getDirectionsURL()`, `EventLocationSection` "Get Directions" button |
| Add/remove coaches present | ✅ | `CoachesPresentSection`, `addCoach()`, `removeCoach()`, picker + remove button |
| Log performance metrics | ✅ | `MetricsSectionView`, `EventMetricForm`, `addMetric()`, `deleteMetric()` |
| Quick-log interactions (type, direction, content, sentiment) | ✅ | `QuickLogInteractionSheet` (type, direction, sentiment, notes, optional coach) |
| Load event by ID, refresh on mutations | ✅ | `loadAll()`, `loadRelatedData()`, `fetchCoaches`, `fetchMetrics` |
| Error banner with retry | ✅ | `errorState(message:)`, alert with Retry/OK |
| Pull-to-refresh | ✅ | `.refreshable { await viewModel.loadAll() }` |
| Data models | ✅ | `FullEvent` (incl. `coachesPresent`), `Coach`, `PerformanceMetric`, `InteractionData`, `EditEventData`, `NewMetricData` |
| Service API | ✅ | `EventsManaging` + `EventsServiceImpl`: fetchEvent, updateEvent, deleteEvent, fetchCoaches, fetchMetrics, createMetric, deleteMetric, createInteraction |
| Accessibility (labels, hints, 44pt targets) | ✅ | Labels on sections, buttons, metrics, coaches; `EventDetailAccessibilityTests` |
| Haptic feedback | ✅ | `HapticFeedbackManager` on success/error/warning |

### 1.2 Gaps (Not Yet Implemented or Spec Divergent)

| Gap | Spec reference | Current behavior | Priority |
|-----|----------------|------------------|----------|
| **Export metrics (PDF/CSV)** | §1 Key User Actions; §6 Metrics Section "Export button (icon)" | No export; no `showExportModal` or export flow | **High** |
| **Event not found** | §2 Error: "Event not found" + CTA "Return to Events →"; §8 Data Errors | Generic error + Retry only; no distinction for 404 | **High** |
| **Coaches Present always visible** | §6 "Empty state: 'No coaches recorded' or 'Event not linked to school'" | Section only shown when `coachesAtEvent` or `availableCoaches` non-empty | **Medium** |
| **Metrics section header wording** | §6 "Metrics Recorded at This Event" | "Performance Metrics" | **Low** |
| **Quick Log: Content required** | §2 "Content (multiline text, required)" | Notes optional; no required validation | **Low** (align if API expects required content) |
| **fetchEvent by user_id** | §4 "`.eq("user_id", currentUserId)`" | Service does not filter by `user_id` (RLS may enforce) | **Low** (verification / defense-in-depth) |

### 1.3 Optional / Polish

- **Navigation title:** Spec says empty nav title with title in content; app uses `navigationTitle(event?.name ?? "Event")`. Acceptable as-is unless strict spec match required.
- **Action buttons:** Spec describes inline "Mark Attended / Edit / Delete" row; app uses toolbar menu (•••). Matches iOS patterns and is acceptable.

---

## 2. Implementation Plan to Complete the Spec

Follow existing patterns: **MVVM**, **protocol-based DI** (`EventsManaging`), **@Observable** ViewModels, **sheet/confirmationDialog** for modals, and **List + Section** in SwiftUI. Test patterns: unit tests for ViewModel with `MockEventsService`, accessibility tests for labels/traits, E2E where needed.

---

### Task 1: Event Not Found Handling (High)

**Goal:** When event load fails with "not found" (e.g. 404 or empty), show dedicated "Event not found" message and "Return to Events" CTA instead of generic error + Retry.

**Pattern reference:** `OfferDetailView` + `OfferDetailViewModel`: separate `offer == nil` with `errorMessage` vs `notFoundView` with "Return to Offers" button.

**Steps:**

1. **EventsServiceImpl**  
   - In `fetchEvent(id:)`, if Supabase returns a "not found" style error (e.g. `.single()` throws with 404 or PGRST116), consider throwing a dedicated error type (e.g. `EventError.notFound`) or an error that the ViewModel can interpret.  
   - Alternatively, keep current throw and in the ViewModel map the caught error to a boolean or enum: `isNotFound(error)` (e.g. check for 404 or "not found" in message).

2. **EventDetailViewModel**  
   - Add: `var isNotFound: Bool = false` (or derive from `error` + last thrown error).  
   - In `loadAll()`, in the `catch`: if the error is "not found", set `isNotFound = true` and optionally `error = "Event not found"` (or leave message for not-found view only).  
   - Ensure `event == nil` when not found so the view shows the not-found state.

3. **EventDetailView**  
   - In `body`, add a branch: if `viewModel.event == nil && viewModel.isNotFound`, show a dedicated view:  
     - Icon (e.g. `doc.questionmark` or `calendar.badge.exclamationmark`).  
     - Text: "Event not found".  
     - Button: "Return to Events" → `dismiss()`.  
   - Reuse or mirror the structure of `OfferDetailView.notFoundView` for consistency.  
   - Ensure VoiceOver and 44pt touch target for the button.

4. **Tests**  
   - **EventDetailViewModelTests:** Mock `fetchEvent` to throw a "not found" error; assert `isNotFound` becomes true and `event` is nil.  
   - **EventDetailE2ETests** (if feasible): Navigate to detail with invalid ID and assert "Event not found" and "Return to Events" are shown.

**Files to touch:**  
- `Features/Events/Services/EventsServiceImpl.swift` (optional: typed error)  
- `Features/Events/ViewModels/EventDetailViewModel.swift`  
- `Features/Events/Views/EventDetailView.swift`  
- `TheRecruitingCompassTests/Features/Events/ViewModels/EventDetailViewModelTests.swift`  
- Optionally `TheRecruitingCompassUITests/Features/Events/EventDetailE2ETests.swift`

---

### Task 2: Coaches Present Section Always Visible with Empty States (Medium)

**Goal:** Always show "Coaches Present" section; when event has no school, show "Event not linked to school"; when school exists but no coaches recorded, show "No coaches recorded".

**Steps:**

1. **EventDetailView**  
   - Change the condition for showing `CoachesPresentSection`.  
   - Currently: `if !viewModel.coachesAtEvent.isEmpty || !viewModel.availableCoaches.isEmpty`.  
   - New: Always show the section (e.g. remove the `if` or make it always true for this section).  
   - Pass a flag or the event’s `schoolId` so the section can choose the right empty state.

2. **CoachesPresentSection**  
   - Add parameters (or derive from existing): e.g. `schoolId: String?` (or `hasSchool: Bool`).  
   - Logic:  
     - If `schoolId == nil`: show header "Coaches Present" and empty state text: "Event not linked to school" (and do not show "+ Add Coach").  
     - If `schoolId != nil` and `coachesAtEvent.isEmpty` and `availableCoaches.isEmpty`: show "No coaches recorded" and "+ Add Coach" (if the add flow can still be used when list is empty from API).  
     - If `schoolId != nil` and `availableCoaches.isEmpty` but `coachesAtEvent` non-empty: show list only (no picker).  
     - Otherwise: current behavior (list + picker).  
   - Ensure empty state text has proper accessibility labels.

**Files to touch:**  
- `Features/Events/Views/EventDetailView.swift`  
- `Features/Events/Components/EventDetail/CoachesPresentSection.swift`

---

### Task 3: Export Metrics (PDF/CSV) (High)

**Goal:** Add an "Export" control in the Metrics section that allows exporting metrics recorded at the event (PDF and/or CSV as per spec).

**Steps:**

1. **Export behavior**  
   - **CSV:** Generate a simple CSV (e.g. metric type, value, unit, date, verified, notes) from `viewModel.metrics`.  
   - **PDF:** Use PDFKit (or equivalent) to generate a one-page (or multi-page) summary of metrics; match app typography where possible.  
   - Spec says "Export metrics recorded at event (PDF/CSV)" and "Export button (icon)" — implement at least one format (CSV is simplest); add PDF if time permits.

2. **EventDetailViewModel**  
   - Add: `var showExportSheet = false` and optionally `exportFormat: ExportFormat` (e.g. `.csv`, `.pdf`).  
   - Add method: `exportMetrics() async` or `prepareExport()` that builds the export data (or URL/document).  
   - On iOS, sharing is often done via `UIActivityViewController` or SwiftUI `sheet(item:)` with a share sheet.  
   - Option A: Generate in-memory CSV/PDF and present share sheet with a temporary file URL.  
   - Option B: Present a small "Export" sheet with "Export as CSV" / "Export as PDF" buttons that trigger generation and then share.

3. **EventDetailView**  
   - In the Metrics section header (or in `MetricsSectionView`), add an Export button (e.g. icon `square.and.arrow.up`).  
   - Tapping it sets `showExportSheet = true` or triggers export flow.  
   - Add a sheet for export options or direct share (depending on UX choice).  
   - Ensure button is disabled when `metrics.isEmpty` and has an accessibility label like "Export metrics".

4. **MetricsSectionView**  
   - Add a trailing button in the section header (or as a second row) for Export; pass in `onExport: () -> Void` and optionally `canExport: Bool` (e.g. `!metrics.isEmpty`).

5. **Tests**  
   - Unit test: ViewModel with mock metrics, call export path and assert file/data is produced (or share intent triggered).  
   - Accessibility: Export button has label and is not focusable when no metrics.

**Files to touch:**  
- `Features/Events/ViewModels/EventDetailViewModel.swift`  
- `Features/Events/Views/EventDetailView.swift`  
- `Features/Events/Components/EventDetail/MetricsSectionView.swift`  
- New (optional): `Features/Events/Utilities/MetricsExportHelper.swift` or similar for CSV/PDF generation  
- `TheRecruitingCompassTests/Features/Events/ViewModels/EventDetailViewModelTests.swift`  
- `TheRecruitingCompassTests/Mocks/MockEventsService.swift` (no change if export is client-only)

---

### Task 4: Minor Spec Alignment (Low)

**4.1 Metrics section header**  
- In `MetricsSectionView`, change header text from "Performance Metrics" to "Metrics Recorded at This Event" (or "Metrics Recorded at Event" if shorter).

**4.2 Quick Log content required (if API requires it)**  
- Spec: "Content (multiline text, required)".  
- If backend expects a required `content` (or `subject`) field:  
  - Rename or map `InteractionData.notes` to `content` for the API if needed.  
  - In `QuickLogInteractionSheet`, make the notes/content field required: show validation and disable Save when empty.  
  - Add accessibility label "Content, required".

**4.3 fetchEvent with user_id (defense-in-depth)**  
- In `EventsServiceImpl.fetchEvent(id:)`, accept `userId: String` (from caller) and add `.eq("user_id", value: userId)` to the query so only the current user’s events are fetchable.  
- Update `EventsManaging` and all call sites (e.g. `EventDetailViewModel.loadAll()` passes `authManager.user?.id`).  
- Ensures alignment with spec §4 and reduces risk if RLS is misconfigured.

**Files to touch:**  
- `MetricsSectionView.swift` (header text)  
- `QuickLogInteractionSheet.swift`, `InteractionData`, `CreateInteractionRequest` (only if making content required)  
- `EventsManaging.swift`, `EventsServiceImpl.swift`, `EventDetailViewModel.swift` (fetchEvent userId)

---

## 3. Testing Checklist (Spec §9) – Coverage After Plan

After implementing the plan:

- **Happy path:** Event loads; edit saves; delete confirms and dismisses; mark attended shows quick log; add/remove coach; add/delete metric; **export metrics**; get directions.  
- **Errors:** **Event not found** shows dedicated message and "Return to Events"; network/retry; update/delete failure alerts.  
- **Edge cases:** **Event with no school** shows "Event not linked to school" in Coaches section; attended event hides "Mark as attended"; VoiceOver and Dynamic Type.

---

## 4. Order of Work

1. **Task 1 (Event not found)** – Small, high impact, unblocks clear error UX.  
2. **Task 2 (Coaches empty states)** – Quick UI change.  
3. **Task 4.1 (Metrics header)** – Trivial.  
4. **Task 3 (Export metrics)** – Highest effort; can be CSV first, then PDF.  
5. **Task 4.2 (Quick Log required)** – Only if product/API require it.  
6. **Task 4.3 (fetchEvent user_id)** – Quick service + ViewModel change.

---

## 5. Sign-Off

- **Spec read:** `iOS_SPEC_Phase6_EventDetail.md` (web repo).  
- **Implementation verified:** Event Detail view, ViewModel, service, and Event Detail components (header, location, details, coaches, metrics, edit sheet, quick log sheet) are in place and match most of the spec.  
- **Remaining work:** Export metrics, event-not-found UX, coaches section always visible with correct empty states, and minor wording/API alignments as above.  
- **Ready for implementation:** Yes; this plan uses existing patterns (OfferDetail not-found, List/Section, toolbar, sheets) and does not require new architecture.
