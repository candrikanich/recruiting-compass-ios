# App Store Launch Checklist

Track every required item before submitting to App Store Review.
Update status as you go: `[ ]` → `[~]` (in progress) → `[x]` (done).

**Legend:** 🔴 Blocker (rejection risk) · 🟡 Important · 🟢 Done

---

## 1. App Store Connect Account Setup
- [x] 🟢 Developer account verified
- [x] 🟢 Tax and banking details complete
- [x] 🟢 All agreements signed
- [ ] 🟡 App record created in App Store Connect
- [ ] 🟡 Bundle ID registered (`com.chrisandrikanich.TheRecruitingCompass`)

---

## 2. Build Prep
- [x] 🟢 Bundle ID matches entitlements (`com.chrisandrikanich.TheRecruitingCompass`)
- [x] 🟢 Team ID set (`G374A783RH`)
- [x] 🟢 Entitlements file correct (associated domains only)
- [x] 🟢 **PrivacyInfo.xcprivacy created** (UserDefaults declared, CA92.1)
- [ ] 🔴 Version number set to shipping version (currently `1.0` — confirm this is intentional)
- [ ] 🔴 Build number bumped before each upload (currently `1`)
- [ ] 🟡 Release.xcconfig has real production credentials (not placeholders)
- [ ] 🟡 Archive build tested on a physical device before submission
- [ ] 🟡 No DEBUG-only code paths reachable in release build

---

## 3. Assets
- [x] 🟢 1024×1024 app icon, RGB (no alpha channel)
- [x] 🟢 All icon sizes present (20pt–1024pt)
- [ ] 🔴 Screenshots for every required device size:
  - [ ] iPhone 6.9" (iPhone 16 Pro Max / 15 Pro Max)
  - [ ] iPhone 6.7" (iPhone 16 Plus / 15 Plus)
  - [ ] iPhone 6.5" (iPhone 11 Pro Max / XS Max) — required if targeting iOS 12+
  - [ ] iPad Pro 13" (if iPad supported)
  - [ ] iPad Pro 12.9" 2nd gen (if iPad supported)
- [ ] 🟡 App preview video (optional but helps conversion)
- [ ] 🟡 Screenshots show dark mode if app supports it

---

## 4. Metadata
- [ ] 🔴 App name confirmed (currently "myCompass" — verify this is final)
- [ ] 🔴 Description written (max 4000 chars)
- [ ] 🔴 Keywords filled (max 100 chars — choose carefully, can't change post-launch without update)
- [ ] 🔴 Subtitle written (max 30 chars)
- [ ] 🔴 Category selected (matches what app actually does)
- [ ] 🔴 Age rating questionnaire completed honestly
- [ ] 🔴 Privacy policy URL live and accessible: `https://myrecruitingcompass.com/privacy`
- [ ] 🔴 Support URL live and accessible: `https://myrecruitingcompass.com` or dedicated support page
- [ ] 🟡 Copyright string correct (e.g. `© 2026 Chris Andrikanich`)
- [ ] 🟡 Promotional text written (optional, 170 chars, can update without app update)
- [ ] 🟡 What's New text for v1.0 (shown on update pages — still good to have for first release)

---

## 5. Privacy & Permissions
- [x] 🟢 `NSFaceIDUsageDescription` in build settings
- [x] 🟢 `PrivacyInfo.xcprivacy` present with UserDefaults reason declared
- [x] 🟢 No ATT required (app does not track across other apps/websites)
- [ ] 🔴 **Privacy Nutrition Labels completed in App Store Connect:**
  - [ ] Email Address (collected for account creation / login)
  - [ ] User ID (Supabase auth UID — linked to user)
  - [ ] Usage Data (if Supabase logs queries — check with Supabase data practices)
  - [ ] Crash Data (if using any crash reporter)
- [ ] 🟡 PHPickerViewController confirmed as only photo access (no NSPhotoLibraryUsageDescription needed ✅)
- [ ] 🟡 CoreLocation/MapKit used for geocoding only — no location permission requested ✅

---

## 6. Technical
- [ ] 🔴 Zero crashes on release build — run on physical device, exercise all major flows
- [ ] 🔴 Tested on real devices (not just Simulator):
  - [ ] iPhone with Face ID (iPhone X or later)
  - [ ] iPhone without Face ID (SE 3rd gen) — optional but good
- [ ] 🔴 All 3rd-party SDKs up to date (Supabase Swift SDK)
- [ ] 🟡 App size verified < 200MB for OTA install
- [ ] 🟡 Dark mode tested — most colors are hardcoded RGB in AppColors.swift; do a full visual pass
- [ ] 🟡 Dynamic Type tested — use at least 2 sizes larger than default
- [ ] 🟡 VoiceOver pass on critical flows (login, dashboard, settings)
- [ ] 🟡 Deep links verified on device (`myrecruitingcompass.com` AASA file live and valid)
- [ ] 🟡 Network offline state handled gracefully

---

## 7. Final Pre-Submission
- [ ] 🔴 **Demo account credentials** in Review Notes if app requires login:
  - Email: `[add demo email]`
  - Password: `[add demo password]`
- [ ] 🔴 Review notes explain any non-obvious flows (Face ID opt-in, family codes, etc.)
- [ ] 🟡 Contact email in App Store Connect is current
- [ ] 🟡 Run Xcode → Product → Archive → Validate App (catches common issues before upload)
- [ ] 🟡 TestFlight beta tested by at least 1 external tester before App Store submission
- [ ] 🟡 `HANDOFF-about-page.md` and other working files cleaned up from repo root before public release

---

## 8. Post-Submission
- [ ] 🟡 Monitor Resolution Center for reviewer questions
- [ ] 🟡 App Store page live — check screenshots, description render correctly
- [ ] 🟡 Deep link / universal link tested from Safari after app is installed from App Store

---

## Already Done ✅
| Item | Status |
|---|---|
| App icon (1024×1024, RGB, no alpha) | ✅ |
| NSFaceIDUsageDescription | ✅ |
| PrivacyInfo.xcprivacy | ✅ (created 2026-03-08) |
| Release.xcconfig gitignored | ✅ |
| SupabaseConfig.generated.swift gitignored | ✅ |
| Entitlements (associated domains) | ✅ |
| No ATT framework needed | ✅ |
| Bundle ID / Team ID | ✅ |

---

*Last updated: 2026-03-08*
*Next review: Before TestFlight external beta*
