# Swift / SwiftUI Code Review

**Date:** February 19, 2026  
**Scope:** Current branch vs main; modern Swift/SwiftUI standards for iOS apps  
**Reference:** Apple SwiftUI documentation (Context7: `/websites/developer_apple_swiftui`)

---

## Executive Summary

The codebase is already aligned with many modern Swift/SwiftUI practices: **@Observable** + **@MainActor** ViewModels, **@State** in views, **.task** for async loading, **NavigationStack**, semantic fonts for text, and strong accessibility (labels, hints, 44pt targets). The review below suggests incremental improvements for consistency, maintainability, and alignment with the latest Apple guidance.

---

## What’s Already in Good Shape

### State Management (iOS 17+ Observation)

- ViewModels use **@Observable** and **@MainActor**; views use **@State private var viewModel**.
- This matches Apple’s migration guidance: *“Use the Observable macro when adding observation support to your type”* and *“SwiftUI automatically tracks observable properties read within a view’s body.”*
- **ActivityFeedViewModel** uses a **nonisolated deinit** to avoid test crashes when the object is deallocated outside a task context—a documented workaround in your CODE_PATTERNS.

### Async and Lifecycle

- **.task { await viewModel.load… }** is used for one-shot load on appear; SwiftUI cancels the task when the view disappears or identity changes.
- **RecentActivityWidget** correctly cancels a stored **Task** in **onDisappear** and **onChange(of: scenePhase)** before starting cleanup, avoiding overlapping unsubscribe work.

### Navigation and Presentation

- **NavigationStack** is used (no **NavigationView**), which is correct for modern iOS.
- Sheets use **.sheet(isPresented:)** with **@State**; Legal and Settings flows are clear.

### Accessibility

- Interactive elements use **.accessibilityLabel** and **.accessibilityHint**.
- Loading states use **.accessibilityElement(children: .combine)** with a single label.
- Section headers use **.accessibilityAddTraits(.isHeader)** for rotor navigation.
- Buttons and links use **.frame(minWidth: 44, minHeight: 44)** or **.frame(minHeight: 44)** for touch targets (WCAG 2.5.5).
- **LegalEmailLink** uses a spoken form for the address (“ at ”, “ dot ”) for VoiceOver.

### Typography and Theming

- Body and headings use semantic fonts (**.headline**, **.body**, **.caption**).
- **.font(.system(size: iconSize))** is reserved for SF Symbol icons, with **iconSize** derived from **@Environment(\.sizeCategory)** where appropriate (per CODE_PATTERNS).

### Structure

- Legal content is factored into **LegalSectionHeader**, **LegalSubsectionHeader**, **LegalBodyText**, **LegalBulletList**, **LegalEmailLink** in **LegalContentViews.swift**, reducing duplication between Privacy Policy and Terms of Service.

---

## Suggestions for Improvement

### 1. Theme Consistency in ErrorStateView

**Current:** Message text uses **.foregroundStyle(.secondary)**.  
**Suggestion:** Use **Color.secondaryText** (or your theme equivalent) so error states match the rest of the app and respect light/dark and future theming.

**Reference:** Keeps all user-facing secondary text on the same semantic color.

---

### 2. LocalizedStringKey / String Catalogs for User-Facing Strings

**Current:** Navigation titles, button labels, and error messages are plain **String** literals (e.g. `"Terms and Conditions"`, `"Back"`, `"Unable to load Terms of Service"`).  
**Suggestion:** Use **LocalizedStringKey** (or add a String catalog) for all user-facing copy so the app is localization-ready and consistent with Apple’s guidance.

**Impact:** Enables localization and keeps copy in one place; no behavioral change.

---

### 3. Shared “Legal Document” ViewModel Abstraction

**Current:** **PrivacyPolicyViewModel** and **TermsOfServiceViewModel** are almost identical (lastUpdated, isLoading, errorMessage, load, retry).  
**Suggestion:** Introduce a small shared abstraction, e.g. a **LegalDocumentViewModel** protocol or a single generic ViewModel that takes a “document” type (e.g. `PrivacyPolicy.bundled` vs `TermsOfService.bundled`) and a formatted-date closure. This reduces duplication and keeps behavior in sync.

**Impact:** Less code, single place for loading/retry/error behavior.

---

### 4. Open URL via Environment (LegalEmailLink)

**Current:** **LegalEmailLink** uses **UIApplication.shared.open(url)** inside a **Task { @MainActor in … }**.  
**Suggestion:** Prefer **@Environment(\.openURL)** and call **openURL(url)** where possible, so the same code works in widgets and other contexts and stays within SwiftUI’s environment. Fall back to **UIApplication.shared** only when **openURL`** is not available (e.g. older deployment target).

**Reference:** Aligns with SwiftUI’s environment-based API for opening URLs.

---

### 5. Outdated Comments in AddSchoolViewModel Extensions

**Current:** **AddSchoolViewModel+Autocomplete**, **+Enrichment**, and **+DuplicateDetection** still say state “lives in AddSchoolViewModel as **@Published** properties.”  
**Suggestion:** Update to “observable properties” (or “@Observable-backed properties”) since the main ViewModel uses **@Observable** and plain **var**s.

**Impact:** Documentation only; avoids confusion during future refactors.

---

### 6. Optional: nonisolated deinit on Legal ViewModels

**Current:** **ActivityFeedViewModel** uses **nonisolated deinit {}** to avoid test crashes when the instance is deallocated outside a MainActor task. **PrivacyPolicyViewModel** and **TermsOfServiceViewModel** do not.  
**Suggestion:** Only add **nonisolated deinit** to Legal ViewModels if you see similar crashes in tests (e.g. when using **UIHostingController** with these ViewModels). Otherwise leave as-is to avoid unnecessary boilerplate.

---

### 7. Date Formatting for “Last Updated”

**Current:** **TermsOfService** and **PrivacyPolicy** each use **DateFormatter** with **.dateStyle = .long** in a computed **formattedDate**.  
**Suggestion:** If the format is always the same, consider a shared helper (e.g. **DateFormatter.legalDocumentDate** or an extension) so locale/calendar behavior is consistent and easier to change later.

**Impact:** Consistency and one place to adjust for accessibility/locale.

---

### 8. Sheet Presentation for Multiple Legal Screens

**Current:** **SettingsView** uses two **@State** booleans (**showTermsOfService**, **showPrivacyPolicy**) and two **.sheet(isPresented:)** modifiers.  
**Suggestion:** For two sheets this is fine. If you add more (e.g. licenses, consent), consider **.sheet(item:)** with an enum (e.g. **LegalDocument.terms**, **.privacy**) to avoid a growing number of booleans and modifiers.

**Impact:** Scales better if more legal/document sheets are added.

---

## Summary Table

| Area              | Status        | Action |
|------------------|---------------|--------|
| @Observable usage| ✅ Aligned    | None. |
| .task lifecycle  | ✅ Aligned    | None. |
| Cleanup / cancel | ✅ Aligned    | None. |
| NavigationStack  | ✅ Aligned    | None. |
| Accessibility    | ✅ Strong     | None. |
| Semantic fonts   | ✅ Correct    | None. |
| ErrorStateView   | ⚠️ Minor      | Use theme color for message text. |
| Localization     | ⚠️ Opportunity | Introduce LocalizedStringKey / String catalog. |
| Legal ViewModels | ⚠️ Duplication | Optional shared abstraction. |
| LegalEmailLink   | ⏸️ Deferred   | Keep UIApplication.shared.open until openURL returns a result. |
| Comments         | ⚠️ Stale      | Update AddSchoolViewModel extension comments. |
| Date formatting  | ⚠️ Optional  | Shared formatter for “Last updated”. |
| Multi-sheet      | ✅ OK for now | Consider .sheet(item:) if more legal docs added. |

---

## References

- Apple SwiftUI: Migrating from ObservableObject to the Observable macro  
- Apple SwiftUI: **View.task** (lifecycle and cancellation)  
- Apple SwiftUI: **accessibilityLabel** / **accessibilityHint**  
- Project: **CLAUDE.md**, **docs/CODE_PATTERNS.md**
