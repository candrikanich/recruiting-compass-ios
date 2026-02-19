# Privacy Policy Implementation Plan

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase6_PrivacyPolicy.md`
**Web Reference:** `recruiting-compass-web/pages/legal/privacy.vue`
**iOS Project:** TheRecruitingCompass
**Priority:** Phase 6 - Polish & Edge Cases
**Complexity:** Low

---

## Summary

Implement a Privacy Policy screen for the iOS app that mirrors the Nuxt web implementation. Use bundled static content (no API), 12 sections with h2/h3 hierarchy, Last Updated date, contact box with tappable email links, and support for navigation from signup (TermsCheckbox Privacy link).

---

## Architecture

### Feature Location
```
TheRecruitingCompass/Features/Legal/
├── Models/
│   └── PrivacyPolicy.swift
├── ViewModels/
│   └── PrivacyPolicyViewModel.swift
├── Views/
│   └── PrivacyPolicyView.swift
└── Components/
    └── (none - view is self-contained)
```

### Data Model
```swift
struct PrivacyPolicy {
  let content: String
  let lastUpdated: Date
  let version: String

  var formattedDate: String { ... }
}
```

### Approach
- **Content:** Hardcoded bundled Markdown/text (matches web - no dynamic fetch for MVP)
- **Date:** Static "Last Updated" (e.g., February 19, 2026)
- **Acknowledgment:** Defer to future phase (web doesn't have it)
- **Manage Settings:** Defer (optional per spec)

---

## Implementation Tasks

### Task 1: Models & Service
- Create `PrivacyPolicy.swift` with `content`, `lastUpdated`, `version`, `formattedDate`
- Create `PrivacyPolicyService` (or use static content in ViewModel for MVP) that returns bundled policy

### Task 2: ViewModel
- `PrivacyPolicyViewModel`: @Observable, @MainActor
- Properties: `policyContent`, `lastUpdated`, `isLoading`, `errorMessage`
- Method: `loadPolicy()` - loads bundled content (sync for bundled)
- Use `AttributedString(markdown:)` for rendering if content is Markdown

### Task 3: View
- `PrivacyPolicyView`: NavigationStack with back button, title "Privacy Policy"
- Header: "Last Updated: [Date]" (gray, small)
- ScrollView with 12 sections (h2, h3, lists) matching web content
- Contact box: gray background, rounded corners, "Recruiting Compass", privacy@recruitingcompass.com, support@recruitingcompass.com as tappable `mailto:` links
- Loading state: ProgressView + "Loading Privacy Policy..."
- Error state: icon, "Unable to load Privacy Policy", "Retry" button, fallback to bundled if possible
- Design: Use AppColors, semantic fonts, 20pt padding, 16pt between sections

### Task 4: Content (12 Sections)
Copy from web `privacy.vue`:
1. Introduction
2. Information We Collect (h3: Information You Provide, Automatically Collected Information)
3. How We Use Your Information
4. Sharing Your Information
5. Data Security
6. Retention of Information
7. Your Privacy Rights
8. Cookies and Tracking Technologies
9. Third-Party Links
10. Children's Privacy
11. Changes to This Privacy Policy
12. Contact Us (with contact box)

### Task 5: Navigation & Wiring
- Add `PrivacyPolicyView` to navigation (sheet or NavigationLink)
- Update `TermsCheckbox`: Add `onPrivacyPressed: () -> Void` (separate from `onTermsPressed`)
- Wire SignupView: `onPrivacyPressed: { showPrivacyPolicy = true }`, present `PrivacyPolicyView` as sheet
- Ensure Settings/other entry points can open Privacy Policy (if applicable)

### Task 6: Email Links
- Use `Link("privacy@recruitingcompass.com", destination: URL(string: "mailto:privacy@recruitingcompass.com")!)` or `.onTapGesture` with `UIApplication.shared.open(mailtoURL)`
- Handle Mail app unavailable: show alert "Email not available on this device"

---

## Web Content Reference (Full Text)

See `recruiting-compass-web/pages/legal/privacy.vue` for exact copy. Last Updated format: `toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })` → e.g. "February 19, 2026"

---

## Testing Requirements
- Unit: PrivacyPolicyViewModel `loadPolicy`, formattedDate, error handling
- Unit: PrivacyPolicy model
- E2E: Navigate to Privacy Policy from signup, scroll, back
- E2E: Email links open Mail (or alert if unavailable)
- A11y: VoiceOver labels, heading navigation, Dynamic Type, 44pt touch targets

---

## Files to Create
1. `Features/Legal/Models/PrivacyPolicy.swift`
2. `Features/Legal/ViewModels/PrivacyPolicyViewModel.swift`
3. `Features/Legal/Views/PrivacyPolicyView.swift`
4. `TheRecruitingCompassTests/**/PrivacyPolicy*Tests.swift` (unit)
5. `TheRecruitingCompassUITests/**/PrivacyPolicy*E2ETests.swift` (E2E)
6. `TheRecruitingCompassTests/Accessibility/PrivacyPolicyAccessibilityTests.swift` (a11y)

## Files to Modify
1. `Features/Auth/Components/TermsCheckbox.swift` - Add `onPrivacyPressed`
2. `Features/Auth/Views/SignupView.swift` - Wire `onPrivacyPressed`, present sheet

---

## Success Criteria
- [ ] Privacy Policy displays all 12 sections
- [ ] Last Updated date correct
- [ ] Contact box with tappable emails
- [ ] Back button works
- [ ] Accessible from signup (Privacy link)
- [ ] WCAG AA compliant (VoiceOver, Dynamic Type, contrast)
