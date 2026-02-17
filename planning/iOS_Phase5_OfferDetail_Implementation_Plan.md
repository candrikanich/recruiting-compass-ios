# iOS Phase 5 Offer Detail – Implementation Plan

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase5_OfferDetail.md`  
**Status:** Spec largely implemented; two gaps and one optional enhancement.  
**Date:** February 17, 2026

---

## 1. Verification Summary

### 1.1 What Is Already Implemented ✅

| Spec requirement | Implementation | Location |
|------------------|----------------|----------|
| View offer by ID | `OfferDetailView(offerId:)`, `loadOffer()` | `OfferDetailView.swift`, `OfferDetailViewModel.swift` |
| Status badge + school name | `OfferHeaderView` | `OfferHeaderView.swift` |
| Financial summary (Amount, %, Deadline) | `OfferFinancialSummary` with 3 cards, color-coded deadline | `OfferFinancialSummary.swift` |
| Offer details grid (dates, conditions, notes) | `OfferDetailsGrid` | `OfferDetailsGrid.swift` |
| Scholarship calculator | `ScholarshipCalculatorView` (expandable, breakdown, Save to Offer) | `ScholarshipCalculatorView.swift` |
| Edit mode + form | `OfferEditForm`, `startEditing` / `cancelEditing` / `saveChanges` | `OfferEditForm.swift`, `OfferDetailViewModel.swift` |
| Delete with confirmation | `confirmDelete()` → alert → `deleteOffer(onSuccess: dismiss)` | `OfferDetailView.swift`, ViewModel |
| Not found state | "Offer not found" + "Return to Offers" | `OfferDetailView.notFoundView` |
| Data: fetch/update/delete | `fetchOffer(id:)`, `updateOffer(id:data:)`, `deleteOffer(id:)` + `fetchSchool(id:)` | `OffersManaging`, `OffersServiceImpl` |
| Edit form data | `OfferEditData` (init from Offer), `OfferUpdateRequest` | `OfferEditData.swift` |
| Deadline urgency | `DeadlineUrgency`, color/label, overdue/critical/urgent/normal | `DeadlineUrgency.swift`, `Offer` |
| Loading / pull-to-refresh | Full-page loading, `.refreshable { await viewModel.loadOffer() }` | `OfferDetailView.swift` |
| Alerts (error, delete confirm, delete error) | `OfferAlertType`, `alertForType` | `OfferDetailView.swift`, `OfferAlertType.swift` |
| Unit / accessibility / E2E tests | ViewModel, components, navigation/editing/delete/calculator E2E | `OfferDetailViewModelTests`, `OfferDetailAccessibilityTests`, `OfferDetail*E2ETests` |

The app uses **Supabase** directly (`OffersServiceImpl`) rather than REST `/api/offers/:id`; behavior matches the spec (fetch by ID, update, delete, auth via session).

---

## 2. Gaps (Must Fix)

### 2.1 Navigation from Offers List to Offer Detail

**Spec (Primary Flow):** “User navigates from Offers List by tapping an offer.”

**Current behavior:** `OffersListView` shows `OfferCard` with checkbox (select for comparison) and delete. There is **no** `NavigationLink` or `navigationDestination` to `OfferDetailView`. Tapping the card only toggles selection.

**Required:** Tapping an offer in the list should push `OfferDetailView(offerId: offer.id)`.

**Pattern to follow:** Same as Schools: `SchoolDestination` + `NavigationLink(value: .detail(school.id))` + `.navigationDestination(for: SchoolDestination.self)` (see `SchoolsListView.swift`, `SchoolDetailView`).

**Implementation steps:**

1. **Add `OfferDestination` enum** (in `Features/Offers/Models/` or next to `OffersListView`).
   - File: `OfferDestination.swift`
   - Content: `enum OfferDestination: Hashable, Sendable { case detail(String) }` (or `case detail(offerId: String)` if you prefer).

2. **Update `OffersListView`** (`OffersListView.swift`):
   - Add `.navigationDestination(for: OfferDestination.self) { destination in ... }`.
   - In the destination switch: `case .detail(let offerId): OfferDetailView(offerId: offerId)`.
   - In `offerCards`, wrap each card in `NavigationLink(value: OfferDestination.detail(offer.id)) { ... }` and use `.buttonStyle(.plain)` so the existing checkbox and delete buttons still receive taps; only non-button area (or the whole card as fallback) pushes to detail.
   - Ensure the list is inside a `NavigationStack` (it already is when presented from `DashboardView.destinationView(for: .offers)`).

3. **Optional UX:** If the card has an explicit “View details” affordance, keep it; otherwise ensure the card’s accessibility hint (“Tap to view offer details”) matches behavior after this change.

4. **Tests:**
   - E2E: Existing `navigateToOfferDetailFromList()` (tap first offer card, then wait for “Offer Details”) should pass once navigation is in place.
   - Consider a unit or UI test that verifies pushing an offer ID presents `OfferDetailView` (if test structure allows).

**Files to touch:**

- **New:** `TheRecruitingCompass/Features/Offers/Models/OfferDestination.swift` (or equivalent path under your project).
- **Edit:** `TheRecruitingCompass/Features/Offers/Views/OffersListView.swift`.

---

### 2.2 Error State: Retry Button on Fetch Failure

**Spec (Error scenarios):** “Error: Fetch fails – User sees: Error banner – Action: Retry button.”

**Current behavior:** On load failure, `OfferDetailView` shows `ErrorStateView(message: error)`. `ErrorStateView` only shows an icon and message; it has **no** Retry action.

**Required:** When offer fetch fails, show an error banner and a **Retry** button that calls `viewModel.loadOffer()` again.

**Options:**

- **A (recommended):** Add an optional `onRetry: (() -> Void)?` to `ErrorStateView`. When non-nil, show a “Retry” button that calls it. Use from Offer Detail: `ErrorStateView(message: error, onRetry: { Task { await viewModel.loadOffer() } })`. Other usages (Coach, School, etc.) keep `onRetry: nil` and behavior unchanged.
- **B:** In `OfferDetailView` only, replace the generic error block with a custom view (e.g. `OfferDetailErrorView`) that shows message + Retry calling `viewModel.loadOffer()`.

**Implementation steps (Option A):**

1. **Edit `ErrorStateView`** (`Shared/Components/ErrorStateView.swift`):
   - Add `var onRetry: (() -> Void)? = nil` (or `let onRetry: (() -> Void)?` in init).
   - In `body`, if `onRetry != nil`, add a “Retry” button that calls `onRetry?()`.
   - Preserve existing accessibility (e.g. label “Retry” or “Retry loading offer details” for context).

2. **Edit `OfferDetailView`** (`OfferDetailView.swift`):
   - Where you show `ErrorStateView(message: error)`, pass `onRetry: { Task { await viewModel.loadOffer() } }`.
   - Ensure Retry clears or that `loadOffer()` clears `errorMessage` on start so the user sees loading then success or error again.

3. **Tests:**
   - Unit: ViewModel’s `loadOffer()` clears error and is idempotent on retry (existing or add).
   - Accessibility: If you add a dedicated label for Retry, add a quick check in `OfferDetailAccessibilityTests` or equivalent.
   - E2E (optional): Simulate failure (e.g. no network / mock 404), then tap Retry and assert loading/result.

**Files to touch:**

- **Edit:** `TheRecruitingCompass/Shared/Components/ErrorStateView.swift`
- **Edit:** `TheRecruitingCompass/Features/Offers/Views/OfferDetailView.swift`

---

## 3. Optional / Minor

### 3.1 Financial Cards Font Size

**Spec (Design system):** “Large font size (32pt) for amounts.”

**Current:** `OfferFinancialSummary` uses `.title2` for values (system size, not 32pt).

**Suggestion:** Treat as design variance unless product explicitly wants 32pt. If you want to match spec literally, in `OfferFinancialSummary` use `.font(.system(size: 32, weight: .bold))` for the amount/percentage values (and consider Dynamic Type with a scaled metric if needed).

### 3.2 “Back to Offers” in Header

**Spec layout:** “[Back Button] ← Back to Offers.”

**Current:** Standard nav bar back button; “Return to Offers” appears only in the **not found** state.

**Suggestion:** No code change required; system back is sufficient. If you ever add a custom “Back to Offers” label in the nav bar, keep it consistent with other detail screens.

---

## 4. Testing Checklist vs Spec (Section 9)

| Spec item | Status |
|-----------|--------|
| Page loads offer correctly | ✅ ViewModel + E2E |
| Financial summary displays correctly | ✅ Components + E2E |
| Edit mode toggles on/off | ✅ ViewModel + E2E |
| Can save changes successfully | ✅ ViewModel + E2E |
| Can delete offer with confirmation | ✅ ViewModel + E2E |
| Scholarship calculator shows correct values | ✅ E2E |
| Back navigation works | ✅ (after list→detail is added) |
| Offer not found shows appropriate message | ✅ notFoundView |
| Network errors handled | ⚠️ Add Retry (Gap 2.2) |
| Invalid form data shows errors | ✅ Edit form / validation as implemented |
| Offer with no deadline | ✅ “No deadline set” |
| Offer with no conditions/notes | ✅ Grid hides empty |
| Very long text fields | ✅ ScrollView / line limits |
| Overdue deadline display | ✅ DeadlineUrgency.overdue + “Overdue” label |

---

## 5. Implementation Order

1. **Navigation list → detail** (Gap 2.1): Add `OfferDestination`, `navigationDestination`, and `NavigationLink` in `OffersListView`. Run E2E to confirm `navigateToOfferDetailFromList()` passes.
2. **Retry on error** (Gap 2.2): Extend `ErrorStateView` with optional `onRetry`, use it in `OfferDetailView`, then run unit and (if added) E2E error-path tests.
3. **Optional:** Adjust financial card font to 32pt if desired (Section 3.1).

---

## 6. Files Summary

| Action | File |
|--------|------|
| **New** | `Features/Offers/Models/OfferDestination.swift` |
| **Edit** | `Features/Offers/Views/OffersListView.swift` |
| **Edit** | `Shared/Components/ErrorStateView.swift` |
| **Edit** | `Features/Offers/Views/OfferDetailView.swift` |
| Optional | `Features/Offers/Components/OfferFinancialSummary.swift` |

---

## 7. Sign-Off

After completing items in Section 5:

- [ ] User can open Offers list and tap an offer to see Offer Detail.
- [ ] On fetch failure, user sees error and a Retry button that reloads the offer.
- [ ] All existing Offer Detail unit, accessibility, and E2E tests pass.
- [ ] No regressions on other screens that use `ErrorStateView` (Coach, School, etc.).

**Spec compliance:** Once the two gaps above are done, the iOS app will fully meet the Phase 5 Offer Detail spec.
