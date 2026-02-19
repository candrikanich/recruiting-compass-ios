# Terms of Service Implementation Plan

> **For Claude:** Agent team: (1) Feature implementation via subagent-driven development, (2) Unit tests, (3) E2E tests, (4) Refactor, (5) A11y audit.

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase6_TermsOfService.md`  
**Web Reference:** `recruiting-compass-web/pages/legal/terms.vue`  
**iOS Project:** TheRecruitingCompass  
**Priority:** Phase 6 - Polish & Edge Cases  
**Complexity:** Low  

**Goal:** Implement a Terms of Service screen that mirrors the Nuxt web implementation: 11 sections, Last Updated date, scrollable content, Back button. No accept/decline flow for MVP (per spec “Known Limitations – Web doesn't implement accept/decline”). Wire signup “Terms of Service” link to open this screen.

**Architecture:** Same pattern as existing Privacy Policy: Legal feature with Models, ViewModels, Views. Bundled static content (no API). Reuse Privacy Policy styling (sectionHeader, subsectionHeader, bodyText, bulletList, AppColors).

**Tech Stack:** SwiftUI, @Observable ViewModel, bundled content, NavigationStack, sheet from SignupView.

---

## Task 1: Model – TermsOfService

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Models/TermsOfService.swift`

**Steps:**
1. Add `TermsOfService` struct with `lastUpdated: Date`, `formattedDate` (DateFormatter long style).
2. Add static `bundled` returning a fixed date (e.g. February 19, 2026) to match spec.
3. Mirror structure of `PrivacyPolicy.swift` (no `content`/`version` in model for MVP; content lives in View).

**Reference:** `Features/Legal/Models/PrivacyPolicy.swift`

---

## Task 2: ViewModel – TermsOfServiceViewModel

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/ViewModels/TermsOfServiceViewModel.swift`

**Steps:**
1. Add `@Observable` `@MainActor` class `TermsOfServiceViewModel`.
2. Properties: `lastUpdated: String = ""`, `isLoading = false`.
3. Method `loadTerms() async`: set loading true, set `lastUpdated = TermsOfService.bundled.formattedDate`, set loading false.
4. Mirror `PrivacyPolicyViewModel` pattern.

**Reference:** `Features/Legal/ViewModels/PrivacyPolicyViewModel.swift`

---

## Task 3: View – TermsOfServiceView (shell + Last Updated + scroll)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Views/TermsOfServiceView.swift`

**Steps:**
1. Add SwiftUI view with `NavigationStack`, title “Terms and Conditions”, toolbar Back button (dismiss), `.task { await viewModel.loadTerms() }`.
2. Loading state: `ProgressView` + “Loading Terms...” (match Privacy loading view).
3. Content: `ScrollView` with “Last Updated: \(viewModel.lastUpdated)” (caption, secondaryText), then placeholder text “Terms content” so view compiles and runs.
4. Use same layout constants as PrivacyPolicyView: `sectionSpacing = 16`, `padding = 20`, `Color.darkSlate`, `Color.secondaryText`.
5. Add `#Preview { TermsOfServiceView() }`.

**Reference:** `Features/Legal/Views/PrivacyPolicyView.swift` (structure only).

---

## Task 4: View – Add 11 Terms sections (content)

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Views/TermsOfServiceView.swift`

**Steps:**
1. Add 11 section computed properties (or inline in ScrollView) matching web `terms.vue`:
   - 1. Agreement to Terms  
   - 2. Use License (with bullet list: modifying/copying, commercial use, decompile, remove copyright, transfer/mirror)  
   - 3. Disclaimer  
   - 4. Limitations  
   - 5. Accuracy of Materials  
   - 6. Links  
   - 7. Modifications  
   - 8. Governing Law  
   - 9. User Accounts (bullets: accurate info, password, responsibility, notify unauthorized use)  
   - 10. Prohibited Activities (bullets: laws, IP, harassing, unauthorized access, viruses)  
   - 11. Contact Information (support@recruitingcompass.com)
2. Use helpers: `sectionHeader(_:)`, `bodyText(_:)`, `bulletList([String])` same as PrivacyPolicyView (or copy from it). No subsection headers needed for Terms.
3. Copy exact wording from `recruiting-compass-web/pages/legal/terms.vue` for each section.
4. Contact section: single body paragraph with support email; use `emailLink("support@recruitingcompass.com")` and contact box style (gray background, rounded) like Privacy section 12.

**Reference:** `pages/legal/terms.vue` (lines 30–179), `PrivacyPolicyView` section helpers.

---

## Task 5: Navigation – SignupView Terms link

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/SignupView.swift`

**Steps:**
1. Add `@State private var showTermsOfService = false`.
2. Add `.sheet(isPresented: $showTermsOfService) { TermsOfServiceView() }`.
3. In `termsSection`, change `TermsCheckbox(..., onTermsPressed: { }, ...)` to `onTermsPressed: { showTermsOfService = true }`.

**Reference:** Existing `showPrivacyPolicy` and `.sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }`.

---

## Testing Checklist (for agents 2–5)

- **Unit:** TermsOfService model formattedDate and bundled; TermsOfServiceViewModel initial state and loadTerms().
- **E2E:** From signup, tap “Terms of Service” link, see “Terms and Conditions” title and back; tap back to return.
- **A11y:** VoiceOver labels for title, back, last updated, section headers; 44pt touch targets; Dynamic Type.
- **Refactor:** Remove duplication with Privacy (shared helpers if any), consistent naming and style.

---

## File Summary

| Action | Path |
|--------|------|
| Create | `Features/Legal/Models/TermsOfService.swift` |
| Create | `Features/Legal/ViewModels/TermsOfServiceViewModel.swift` |
| Create | `Features/Legal/Views/TermsOfServiceView.swift` |
| Modify | `Features/Auth/Views/SignupView.swift` |

No new service or API; bundled content only. Accept/decline and dynamic fetch deferred per spec.
