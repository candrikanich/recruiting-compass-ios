# App Store Submission Plan — The Recruiting Compass

**Created:** 2026-08-29
**Status:** Pre-submission checklist
**Bundle ID:** `com.chrisandrikanich.TheRecruitingCompass`
**Version:** 1.0 (build 1)
**Deployment Target:** iOS 18.0
**Device Family:** iPhone + iPad

---

## 1. App Store Connect Metadata

### Required Fields

| Field | Value / Notes |
|---|---|
| **App Name** | The Recruiting Compass |
| **Subtitle** (30 chars) | `Your Athletic Recruiting Guide` |
| **Promotional Text** (170 chars, editable anytime) | `Track colleges, manage coach outreach, and stay on top of NCAA deadlines — built for high school athletes and their families.` |
| **Categories** | Primary: **Education** · Secondary: **Sports** |
| **Copyright** | © 2026 Chris Andrikanich |
| **Age Rating** | See §3 below |
| **Price** | Free (no IAP) |
| **Availability** | United States (expand later as needed) |
| **Content Rights** | "This app does not contain, show, or access third-party content" (NCAA calendar data is factual/public-domain scheduling info, not copyrighted content) |

### Keywords (100 chars, comma-separated)

```
recruiting,college,NCAA,athlete,high school,sports,coach,scholarship,prospect,recruiting calendar
```

(98 chars — leaves 2 spare. Do NOT include the app name; Apple indexes it automatically.)

### Description (4000 chars max)

> **Chris must review/customize this.** Draft:

```
The Recruiting Compass helps high school athletes and their parents navigate the college recruiting process — from finding the right schools to communicating with coaches and tracking NCAA deadlines.

TRACK YOUR TARGET SCHOOLS
Build and manage your list of prospective colleges. See each school's recruiting status at a glance with an interactive pipeline — from researching to committed. Log every interaction with coaching staff and track your communication history.

COMMUNICATE WITH COACHES
Use smart outreach templates to craft professional emails and messages to college coaches. Templates auto-fill your stats, achievements, and video links so every message is personalized and complete.

STAY ON NCAA DEADLINES
Sport-specific recruiting calendars show contact periods, dead periods, evaluation windows, and key eligibility milestones for all three NCAA divisions. Never miss a critical date.

MEASURE YOUR PROGRESS
Log and track sport-specific performance metrics with formatted displays that match your sport's conventions. See your improvement over time and share your best numbers with coaches.

BUILT FOR FAMILIES
Parents can create a family account and invite their athlete. Both parent and player see the same data — schools, coaches, events, and progress — so the whole family stays aligned.

19 SPORTS SUPPORTED
Football, Baseball, Softball, Basketball, Soccer, Volleyball, Beach Volleyball, Tennis, Golf, Swimming & Diving, Track & Field, Cross Country, Lacrosse, Field Hockey, Wrestling, Gymnastics, Rowing, Ice Hockey, and Water Polo.

FEATURES
• Interactive school pipeline (Researching → Contacted → Visiting → Offer → Committed)
• Coach contact management with interaction logging
• Smart outreach templates with auto-filled player data
• NCAA recruiting calendar by sport, gender, and division
• Sport-specific performance metric tracking
• Timeline with actionable recruiting tasks and guidance
• Dashboard with customizable widgets
• Public profile for sharing with coaches
• Video links management
• Family accounts with shared data access
• COPPA-compliant — ages 13-17 join via parent invitation
• VoiceOver and Dynamic Type accessibility
• Face ID / Touch ID quick unlock
• Push notifications for recruiting updates

PRIVACY FIRST
No ads. No tracking. No data sold. Your recruiting data stays yours.
```

(~1,800 chars — well within 4,000 limit)

### What's New (v1.0)

```
Initial release — start tracking your college recruiting journey today.
```

---

## 2. Screenshots

### Required Sizes

| Device | Size (px) | Required? |
|---|---|---|
| iPhone 6.9" (16 Pro Max) | 1320 × 2868 | **Yes** (covers 6.5"+ requirement) |
| iPhone 6.3" (16 Pro) | 1206 × 2622 | Optional (auto-scales from 6.9") |
| iPad Pro 13" | 2064 × 2752 | **Yes** (if supporting iPad) |

Minimum 2, maximum 10 screenshots per size. **Recommendation: 6-8 screenshots.**

### Recommended Screenshots (in order)

| # | Screen | Caption |
|---|---|---|
| 1 | **Dashboard** (customized widget layout) | `Your recruiting command center` |
| 2 | **Schools List** with pipeline status badges | `Track every school in your pipeline` |
| 3 | **School Detail** with status stepper | `From research to commitment` |
| 4 | **Coach Detail** with interaction history | `Manage every coach relationship` |
| 5 | **Quick Comm** template composer | `Professional outreach in seconds` |
| 6 | **Recruiting Calendar** with sport-specific events | `Never miss an NCAA deadline` |
| 7 | **Timeline** with tasks and guidance | `Know what to do and when` |
| 8 | **Performance Metrics** log | `Track your athletic progress` |

### Capture Method

```bash
# Boot simulator at the right resolution
xcrun simctl boot "iPhone 16 Pro Max"

# Take screenshot
xcrun simctl io booted screenshot ~/Desktop/screenshot_1.png

# Or use Simulator.app: File → Save Screen (⌘S)
```

**Chris action required:** Log into the app with a demo account that has realistic data (schools, coaches, interactions, metrics, calendar events) and capture each screen. Use light mode for primary set; optionally add dark mode as alternates.

---

## 3. App Review Preparation

### Age Rating Questionnaire

| Question | Answer |
|---|---|
| Made for Kids? | **No** (app is for ages 13+, not a "Made for Kids" app) |
| Cartoon/Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content | None |
| Profanity | None |
| Drug/Alcohol/Tobacco | None |
| Horror/Fear | None |
| Mature/Suggestive Themes | None |
| Simulated Gambling | None |
| Medical/Treatment Info | None |
| Contests | None |
| Unrestricted Web Access | None |

**Expected rating: 4+**

### Demo Account for Review

**Chris must provide:**

| Field | Value |
|---|---|
| Demo email | _(create a stable test account)_ |
| Demo password | _(set a simple password)_ |
| Role | Player (shows full feature set) |

**Requirements for the demo account:**
- Pre-populated with 5-10 schools at various pipeline stages
- At least 2-3 coaches with interaction history
- Performance metrics logged
- A family unit with a parent member (so reviewers can see the family flow described)
- Profile mostly complete (shows the value of the app)

### Notes for Reviewers

```
This app helps high school athletes (ages 13+) and their parents manage the college athletic recruiting process.

KEY FEATURES TO TEST:
1. Dashboard — customizable widget layout showing recruiting overview
2. Schools — add/track prospective colleges through a status pipeline
3. Coaches — manage coach contacts and log interactions
4. Quick Comm — template-based outreach to coaches (uses device email/SMS composers)
5. Timeline — recruiting tasks and NCAA guidance
6. Recruiting Calendar — sport-specific NCAA calendar with contact/dead periods

FAMILY SYSTEM:
Parents create accounts and invite their athlete (ages 13-17) via a family code.
Both users see shared data. This is a COPPA compliance measure — minors cannot
create standalone accounts.

NCAA CALENDAR DATA:
Recruiting calendar dates (contact periods, dead periods, evaluation windows)
are sourced from publicly available NCAA rules and regulations. This is factual
scheduling data, not proprietary content.

PUSH NOTIFICATIONS:
The app sends push notifications for recruiting-related events (new offers,
inbound coach contact, upcoming events). Notifications require opt-in.

NO IN-APP PURCHASES:
The app is completely free with no monetization currently.
```

### Common Rejection Risks & Mitigations

| Risk | Status | Notes |
|---|---|---|
| **Missing Privacy Policy URL** | ✅ Done | `https://myrecruitingcompass.com/legal/privacy` |
| **COPPA (Guideline 1.3)** | ✅ Mitigated | Under-13 blocked; 13-17 via parent invite only |
| **Account Deletion (Guideline 5.1.1(v))** | ✅ Implemented | 30-day grace period with cancel, in Settings |
| **Login requirement (Guideline 5.1.1)** | ✅ OK | Login is essential — all data is user-specific |
| **Data collection without purpose (5.1.2)** | ✅ OK | All data directly serves the app's recruiting function |
| **Push notification misuse (4.5.4)** | ✅ OK | Only recruiting-related notifications, user opt-in |
| **Incomplete UI on iPad** | ✅ In progress | Native iPad design underway — shipping as iPhone + iPad |
| **Hardcoded test data** | **VERIFY** | Ensure no test/debug screens ship in Release |
| **APS entitlement mismatch** | ✅ OK | `aps-environment = development` auto-switches to `production` in Release archive |

---

## 4. Privacy & Legal

### App Privacy Nutrition Label (App Store Connect)

**Data Linked to the User:**

| Data Type | Collected | Purpose |
|---|---|---|
| **Name** | Yes | App Functionality |
| **Email Address** | Yes | App Functionality |
| **Phone Number** | Optional | App Functionality (profile) |
| **Physical Address** | No | — |
| **Coarse Location** | Yes | App Functionality (home location for distance calc) |
| **Precise Location** | No | — |
| **Health & Fitness** (height/weight) | Yes | App Functionality (athlete profile) |
| **Photos** | Yes | App Functionality (profile photo) |
| **Contacts** | No | — |
| **User Content** (notes, interactions) | Yes | App Functionality |
| **Search History** | No | — |
| **Browsing History** | No | — |
| **Identifiers** (user ID) | Yes | App Functionality |
| **Purchases** | No | — |
| **Diagnostics** | No | — |

**Data NOT collected:** Anything for tracking or advertising. No third-party analytics.

**Data Used to Track You:** None
**Data Linked to You:** All of the above (user creates an account)

### COPPA Compliance

- Under 13: **Blocked** at signup (DOB validated, unparseable = blocked)
- Ages 13-17: **Parent-mediated** (must join via family invite code from parent account)
- Parental consent: Implicit via parent creating the family and sharing the invite code
- Data minimization: Only recruiting-relevant data collected
- No behavioral advertising or third-party tracking

### Account Deletion (Apple Requirement)

- **Location:** Settings → Account → Request Account Deletion
- **Grace period:** 30 days (user can cancel)
- **API:** `POST /api/account/request-deletion`, `POST /api/account/cancel-deletion`
- **Data removed:** All user data including profile, schools, coaches, interactions, metrics, family membership

### Required Legal URLs

| Document | Status | Action |
|---|---|---|
| **Privacy Policy** | ✅ Done | `https://myrecruitingcompass.com/legal/privacy` |
| **Terms of Service** | ✅ In-app (native view) | Optionally host publicly too |
| **Support URL** | ✅ Done | `https://myrecruitingcompass.com/help` |

---

## 5. Pre-Submission Technical Checklist

### Xcode Project Configuration

| Item | Status | Notes |
|---|---|---|
| Bundle ID | ✅ `com.chrisandrikanich.TheRecruitingCompass` | Registered in App Store Connect? |
| Version | ✅ `1.0` | |
| Build Number | ✅ `22` (current TestFlight) | Increment for each upload |
| Deployment Target | ✅ iOS 18.0 | |
| Device Family | ⚠️ `1,2` (iPhone + iPad) | **Verify iPad layout or change to iPhone-only (`1`)** |
| App Icon | **VERIFY** | Must have 1024×1024 in asset catalog |
| Launch Screen | ✅ Auto-generated | |
| Encryption (ITSAppUsesNonExemptEncryption) | ✅ `NO` | Supabase uses HTTPS (exempt) |

### Entitlements

| Entitlement | Status | Notes |
|---|---|---|
| Push Notifications (`aps-environment`) | ✅ `development` | Auto-switches to `production` in archive |
| Associated Domains | ✅ `applinks:myrecruitingcompass.com` | **Verify AASA file is served** |
| Keychain Sharing | Not present | Not needed (single app) |
| App Groups | Not present | Not needed |

### Privacy Manifest (PrivacyInfo.xcprivacy)

| Field | Status |
|---|---|
| `NSPrivacyTracking` | ✅ `false` |
| `NSPrivacyTrackingDomains` | ✅ Empty |
| `NSPrivacyAccessedAPITypes` | ✅ UserDefaults (CA92.1) |
| `NSPrivacyCollectedDataTypes` | ✅ Populated (8 types: Name, Email, Phone, Coarse Location, Health, Photos, User Content, User ID) |

### Usage Description Strings

| Key | Present | Value |
|---|---|---|
| `NSFaceIDUsageDescription` | ✅ | "Sign in quickly and securely with Face ID" |
| `NSLocationWhenInUseUsageDescription` | ✅ | "Your current location is used to quickly set your Home Location in settings." |
| `NSCameraUsageDescription` | N/A | Not used |
| `NSPhotoLibraryUsageDescription` | N/A | PhotosPicker doesn't require it (iOS 17+) |

### Release.xcconfig

| Field | Status |
|---|---|
| `SUPABASE_URL` | ✅ Production URL set |
| `SUPABASE_ANON_KEY` | ✅ Production key set |
| `API_BASE_URL` | ✅ `https://myrecruitingcompass.com` |

### App Transport Security

✅ Default (enforced). No `NSAllowsArbitraryLoads`. All connections use HTTPS.

### Build & Archive

```bash
# 1. Clean build folder
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass

# 2. Archive (Xcode GUI preferred for signing)
# Product → Archive (with "Any iOS Device" selected)

# 3. Or via CLI:
xcodebuild archive \
  -scheme TheRecruitingCompass \
  -archivePath ~/Desktop/TheRecruitingCompass.xcarchive \
  -configuration Release \
  -destination 'generic/platform=iOS'

# 4. Upload via Xcode Organizer → Distribute App → App Store Connect
```

**Xcode beta note:** Per project memory, Apple rejects archives from non-latest Xcode betas. Ensure the current Xcode beta is up to date before archiving.

---

## 6. Launch Timeline

| Day | Task |
|---|---|
| **Day 1** | Create App Store Connect app record. Fill metadata (name, description, keywords, categories). Set up Privacy Policy + Support URLs. |
| **Day 2** | Create demo account with realistic data. Capture screenshots on iPhone 16 Pro Max (and iPad Pro 13" if supporting iPad). |
| **Day 3** | Complete App Privacy nutrition label in App Store Connect. Fill age rating questionnaire. Write reviewer notes. |
| **Day 4** | Verify Release.xcconfig has production credentials. Build archive in Xcode. Upload to App Store Connect via Organizer. |
| **Day 5** | Select build in App Store Connect. Final review of all metadata. Submit for review. |
| **Days 6-8** | App Review (typical: 24-48 hours, can be up to 7 days for first submission). Respond to any reviewer questions promptly. |
| **Day 8-9** | Approved → Release (manual or automatic). |

**Total: ~1-2 weeks from start to live.**

---

## 7. Action Items Summary

### Must Do Before Submission

- [x] **Host Privacy Policy at a public URL** — `https://myrecruitingcompass.com/legal/privacy`
- [x] **Create a Support URL** — `https://myrecruitingcompass.com/help`
- [x] **App Store Connect app record** — exists at https://appstoreconnect.apple.com/apps/6758562332
- [ ] **Create demo account** with realistic pre-populated data (schools, coaches, metrics)
- [ ] **Verify app icon** — 1024×1024 in asset catalog (AppIcon)
- [x] **iPad layout** — native iPad design in progress, shipping as iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`)
- [ ] **Capture screenshots** — minimum: 6.9" iPhone (1320×2868); also iPad 13" if supporting iPad
- [ ] **Verify AASA file** — `myrecruitingcompass.com/.well-known/apple-app-site-association` must serve correct JSON
- [ ] **Fill App Privacy nutrition label** in App Store Connect (see §4 mapping above)
- [x] **Verify Release archive builds** — v1.0 build 1, 0 errors, signed Apple Development
- [ ] **Increment build number** for each upload attempt

### Nice to Have

- [ ] App Preview video (15-30 seconds, optional but impactful)
- [ ] Localized screenshots with device frames and captions (tools: Fastlane Frameit, Screenshots Pro)
- [x] Populate `NSPrivacyCollectedDataTypes` in xcprivacy to match nutrition label

### Post-Launch

- [ ] Monitor App Store Connect for crash reports
- [ ] Set up App Store review response strategy
- [ ] Plan v1.1 with any reviewer-requested changes
- [ ] Consider TestFlight beta for future releases
