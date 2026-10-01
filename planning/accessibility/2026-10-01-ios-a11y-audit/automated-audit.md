# Automated audit results (Xcode `performAccessibilityAudit`)

Run on 2026-10-01 against commit `d775d198` on an iPhone 17 simulator (iOS 27.2) with
`TheRecruitingCompassUITests/E2E/AccessibilityAuditTests.swift`. Logged-out screens need no backend; signed-in screens
used the local Supabase stack and the demo player account from `scripts/seed-demo-screenshots.ts`, read-only.

**759 issues across 28 screens.** Counts are an upper bound: a few items are elements partly covered by the floating tab bar or the sticky email-verification banner at the moment of capture.

| Run | contrast | dynamicType | elementDetection | hitRegion | sufficientElementDescription | textClipped | Total |
|---|---|---|---|---|---|---|---|
| light | 268 | 50 | 3 | 22 | 2 | 95 | 440 |
| dark | 100 | 50 | 3 | 22 | 2 | 95 | 272 |
| largest-text | 27 | 1 | 1 | 0 | 0 | 18 | 47 |

By summary: Contrast nearly passed 227, Text clipped 208, Contrast failed 168, Dynamic Type font sizes are partially unsupported 101, Hit area is too small 44, Potentially inaccessible text 7, Label not human-readable 2, Element has no description 2.

## Coverage

Audited: activity-history, add-new-coach, add-new-school, analytics, coach-emails, coaches-detail, coaches-list, dashboard, deadlines, documents, events, forgot-password, help-center, interactions-detail, interactions-list, landing, login, more, notifications, offers, performance, player-details, public-profile, schools-detail, schools-list, signup-parent, signup-player, signup-role.

Not audited: Recruiting Timeline content (it showed an error state with nothing to audit — it needs the local web
API), any screen that needs data the demo account lacks (documents, document viewer), sheets and forms beyond
Add School / Add Coach, onboarding, family invite flows, the forced-update gate, the Face ID lock, iPad layouts.
At the largest text size the walk captured 22 of the 27 signed-in views (Coach detail, Coach Emails, Help Center and
Notifications were missed). The audit inspects what is on screen, so long screens were audited at the top and after
one scroll only.

## "Contrast failed" per screen

| Screen | Light | Dark | Largest-text |
|---|---|---|---|
| dashboard | 16 | 15 | 4 |
| landing | 11 | 11 | 2 |
| coaches-detail | 10 | 7 | 0 |
| notifications | 4 | 10 | 0 |
| deadlines | 7 | 5 | 0 |
| events | 2 | 1 | 7 |
| signup-role | 4 | 5 | 1 |
| signup-player | 2 | 3 | 1 |
| add-new-school | 2 | 2 | 1 |
| interactions-list | 2 | 0 | 3 |
| schools-list | 2 | 1 | 1 |
| schools-detail | 2 | 2 | 0 |
| public-profile | 2 | 1 | 1 |
| documents | 2 | 0 | 2 |
| signup-parent | 1 | 2 | 1 |
| more | 1 | 1 | 0 |
| analytics | 1 | 1 | 0 |
| coaches-list | 1 | 0 | 1 |
| forgot-password | 0 | 1 | 1 |
| interactions-detail | 0 | 0 | 1 |
| login | 0 | 1 | 0 |

## "Hit area is too small" (light run)

- **coach-emails**: “Retry”
- **coaches-detail**: “kevin.brandt@example.edu”; “Add tag”
- **dashboard**: “Dismiss getting started checklist”; “Getting started progress”
- **documents**: “Filter documents”
- **forgot-password**: “Back to login screen”
- **login**: “Back to welcome screen”
- **notifications**: “Mark all as read”
- **schools-detail**: “Mark not pursuing”; “Website: https://clemsontigers.com. Tap to open in browser.”; “Conference: ACC. Tap to open in browser.”; “Lookup college data from College Scorecard”
- **signup-parent**: “Back to welcome screen”; “Change role selection”; “I agree to the Terms of Service and Privacy Policy”
- **signup-player**: “Back to welcome screen”; “Change role selection”
- **signup-role**: “Back to welcome screen”

## "Text clipped" at the largest text size

- **activity-history**: “Asked about academic fit and roster needs.”; “Email with Stanford University”; “Email with Emory University”; “Coach Hale sent the written offer and timeline for”
- **add-new-school**: “College search”
- **coaches-list**: “Search coaches...”
- **dashboard**: “Manage schools”; “View all coaches”
- **documents**: “Newest First”
- **interactions-detail**: “Occurred at Sep 29, 2026 at 3:00 PM”
- **interactions-list**: “Subject, content...”
- **login**: “Password”; “Email”
- **offers**: “Stanford University”; “Accepted”
- **performance**: “Performance Metrics”
- **schools-list**: “Search schools...”

## "Text clipped" at the default size (light run)

- **activity-history**: “Asked about academic fit and roster needs.”; “Direct Message with Wake Forest University”; “Coach Sandoval texted to follow up after the visit”; “Received questionnaire link and camp invite.”; “Introduced Jordan and linked film.”; “Text with Vanderbilt University”; “Email with Emory University”; “Email with Stanford University”; “Email with University of Virginia”; “Coach Hale sent the written offer and timeline for”; “Official Visit with Vanderbilt University”
- **add-new-school**: “College search”
- **analytics**: “Phone Call”; “Showcase”; “Direct Message”; “Official Visit”; “Camp”; “Virtual Meeting”; “Email”
- **coaches-detail**: “0% rate”; “DAYS SINCE”; “Email”; “INTERACTIONS”; “DIRECT CHANNELS”; “0 logged”; “PREFERRED”; “Log Activity”; “days ago”
- **coaches-list**: “Search coaches...”
- **dashboard**: “View all coaches”; “Manage schools”; “Getting Started”
- **documents**: “Newest First”
- **forgot-password**: “Email”
- **help-center**: “Quick answers to the questions we hear most.”; “Set up your profile and learn the basics of the recruiting d”; “Getting Started”; “Recruiting terms explained in plain language.”; “Add schools, understand fit signals, and track coach interac”; “Schools & Coaches”; “Navigate recruiting phases and manage recommendation letter ”; “Account & Settings”; “Manage your family, notifications, profile, and account pref”
- **interactions-detail**: “School”; “Occurred at Sep 29, 2026 at 3:00 PM”; “Marcus Hale”; “Logged By”; “Stanford University”; “Coach”
- **interactions-list**: “Inbound”; “Stanford University”; “Looking forward to the visit”; “Marcus Hale”; “Coach Hale confirmed the official visit itinerary.”; “Subject, content...”
- **login**: “Email”; “Password”
- **notifications**: “Stanford offer deadline in 35 days”; “It's been 8 days since your official visit. Send a thank-you”; “Review the written offer with your family before the deadlin”; “New offer 🎉”; “Follow up with Vanderbilt”; “🔔”; “🎉”; “Clear read notifications”; “New scholarship offer from Stanford University.”
- **offers**: “Written offer received. Decision deadline set after the offi”; “Accepted”; “Stanford University”
- **performance**: “Performance Metrics”
- **schools-detail**: “https://clemsontigers.com”; “Location data not available”; “Use 'Lookup College Data' to fetch location”; “Quick Comm”; “Log Interaction”; “Manage Coaches”
- **schools-list**: “Search schools...”
- **signup-parent**: “Confirm Password”; “Email”; “Password”
- **signup-player**: “Email”
- **signup-role**: “Track your athletic performance and recruiting status”; “Manage your family's recruiting profile”

## "Dynamic Type font sizes are partially unsupported" (light run)

- **activity-history**: “5 seconds ago”; “Official Visit with Vanderbilt University”
- **coaches-detail**: “0% rate”; “DAYS SINCE”; “0 logged”; “—”; “PREFERRED”; “INTERACTIONS”; “4”; “Keep going”; “0”; “days ago”
- **coaches-list**: “kevin.brandt@example.edu”; “Rice University”; “Last contact: 4d ago”; “Kevin Brandt”
- **help-center**: “Recruiting terms explained in plain language.”; “Quick answers to the questions we hear most.”; “FAQ”; “Glossary”
- **interactions-detail**: “School”; “Logged By”; “You”; “Marcus Hale”; “—”; “Event”; “Stanford University”; “Coach”
- **landing**: “Sports”; “Templates”; “NCAA Calendars”
- **notifications**: “19h ago”; “New offer 🎉”; “HIGH”; “🎉”; “New scholarship offer from Stanford University.”
- **player-details**: “Video Links”; “Highlight and film links coaches can watch”
- **public-profile**: “Recommended: 1200×400 JPG or PNG”
- **schools-detail**: “Researching”
- **schools-list**: “College of Charleston”

## Other

- "Potentially inaccessible text": Performance (6 across runs), School detail (1).
- "Label not human-readable": the coach email link on Coach detail reads only the address.
- "Element has no description": one image on Public Profile.

## What the accessibility trees showed

- Interaction detail: the message body is exposed as a static text labelled `Interaction content` — the body itself is
  not in the tree.
- Add School: each `FormFieldWrapper` field is a generic element ("School Name, required", value = placeholder) with
  an unlabelled text field beneath it.
- Schools list and Coaches list cards: one button with a full composed label plus separate Delete / Add to favorites /
  Email coach buttons — the nested-button concern raised in the static review does not apply to these two lists.
- Dashboard event rows speak the raw type: `official_visit: Stanford Official Visit`.

## Re-running

```sh
cd TheRecruitingCompass
xcrun simctl ui <udid> appearance dark   # or light
TEST_RUNNER_A11Y_AUDIT=1 TEST_RUNNER_A11Y_AUDIT_REPORT_DIR=/tmp/a11y \
TEST_RUNNER_A11Y_AUDIT_CONFIG=dark \
TEST_RUNNER_A11Y_AUDIT_EMAIL=<seeded account> TEST_RUNNER_A11Y_AUDIT_PASSWORD=<password> \
xcodebuild test -scheme TheRecruitingCompass -destination "id=<udid>" -parallel-testing-enabled NO \
  -only-testing:TheRecruitingCompassUITests/AccessibilityAuditTests
```

`A11Y_AUDIT_CONFIG=largest-text` launches the app at the largest accessibility text size. Each run writes
`issues-*.json`, a screenshot and the accessibility tree per screen to the report directory. The signed-in test only
reads: it opens forms but never submits, edits, deletes or signs out.
