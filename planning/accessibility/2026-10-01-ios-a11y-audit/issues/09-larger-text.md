## Problem

At accessibility text sizes many screens truncate, clip or cannot reflow. The app has zero uses of `dynamicTypeSize`, and `AdaptiveHStackVStack` (`Shared/Components/Forms/`) exists but has no call sites. Only the Add School form reflows (`ViewThatFits`). Fonts themselves are fine — semantic text styles almost everywhere.

### A. Screens that may trap the user (potential blockers — verify at AX5 on a small phone)

Fixed `VStack`s with no `ScrollView`, so content that does not fit is cut off and the button may be unreachable:

- Forced-update gate — `Features/AppUpdate/Views/UpdateRequiredView.swift:13-51`
- Sport gate — `Features/Onboarding/Views/SportGateView.swift:80-146` (also a fixed `height: 48` button)
- Push-priming sheet locked to `.medium` — `Features/Onboarding/Views/PushNotificationPrimingView.swift:13-60`, presented at `OnboardingStepTwoView.swift:46-49`
- Birthday-confirm sheet: wheel `DatePicker` + text + Confirm in a `.medium` detent with `interactiveDismissDisabled()` — `Features/Family/Views/InviteJoinBirthdayConfirmView.swift:10-58`, presented at `InviteJoinView.swift:34-37`
- Face ID lock — `Features/Auth/Views/BiometricLockView.swift:16-56`

### B. Measured by the automated audit at the largest text size

At the largest accessibility size the audit reported 18 "Text clipped" items (the walk captured 22 of the 27 signed-in views at that size; Coach detail, Coach Emails, Help Center and Notifications were missed):

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

At the **default** size it reported 95 "Text clipped" and 50 "Dynamic Type font sizes are partially unsupported" items — text that is already truncated, or that will not grow. Worst screens for clipping: Activity History (11), Help Center (9), Notifications (9), Coach detail (9), Analytics (7), Interactions (6 each on list and detail). Worst for Dynamic Type: Coach detail (11), Interaction detail (8), Notifications (5), Help Center (4), Coaches list (4), Landing (3).

On the login screen at the largest size the field labels scale but the text inside the Email and Password fields is reported clipped (`Features/Auth/Components/LoginFormField.swift`).

### C. Multi-column layouts that never reflow

- Coach detail: three-column channel and stat grids with `lineLimit(1)` + `minimumScaleFactor` — `CoachDirectChannelsGrid.swift:15,17-21,51-55` (`sizeCategory` is declared and unused), `CoachStatsGrid.swift:10-14,73-74,90-91,96-97`, `CoachInteractionsLogSection.swift:143-155`.
- Dashboard / Performance / Timeline / Analytics: `PerformanceDashboardView.swift:239-243` (3 columns of `.title` values), `TimelineStatPills.swift:26-56`, `DashboardStatsCardsSection.swift:12`, `AtAGlanceSummary.swift:16-19` + `MetricCard.swift:10-20`, `AnalyticsDashboardView.swift:201-204`, `PieChartView.swift:21-27,92-95`, `SchoolRecommendationsWidget.swift:73-75,97-100,130`.
- School detail: status stepper (five nodes in one `HStack`, `.caption2` labels, fixed 28 pt circles) — `SchoolStatusStepper.swift:29-37,57-64,144`; `SchoolProsConsSection.swift:21-111`, `SchoolQuickActions.swift:16-50,79-85`, `CollegeScorecardDataDisplay.swift:28-34`.
- Offers / Documents: `OfferFinancialSummary.swift:11-59`, `DocumentHeaderCard.swift:34-62`, `ScholarshipCalculatorView.swift:161-186` (five columns with fixed widths), `OfferFilterBar.swift:8-48`.
- Player Profile editor and Public Profile: label + trailing field rows in `BasicsTab.swift:188-207,218-233`, `AthleticsTab.swift:240-258,409-425`, `AcademicsSocialTab.swift:71-89`, `HistoryTab.swift:152-172,183-200,208-224`; three-button choice rows `BasicsTab.swift:294-314`; preview grids `PublicProfileCard.swift:85-89`, `PublicProfileSections.swift:17-20,241-252,300-309`.
- `Shared/Components/InfoRow.swift:9-19` (label/value side by side, 6 call sites); `Features/Help/Views/HelpCenterView.swift:16-19,74` (always two columns).

### D. Essential text truncated with no way to read the rest

- Action-item message `lineLimit(3)`, and its "Learn More" opens generic help, not the message — `ActionItemCard.swift:43-47,82-85`.
- Notification title/message limited to 2/3 lines, and tapping navigates away — `NotificationCard.swift:34,43`.
- School name `.lineLimit(2).minimumScaleFactor(0.9)` — `SchoolDetailHeader.swift:89-93`.
- Coach-log subject `lineLimit(1)` never shown in full — `CoachInteractionsLogSection.swift:228-233`.
- Forwarding address and profile URL `lineLimit(1)` — `ForwardCoachEmailsCard.swift:30-31`, `ShareLinkRow.swift:12-13`.
- Activity rows, top-priority task, metric notes — `ActivityEventItem.swift:33,39`, `DashboardTimelineSummaryCard.swift:84,89`, `MetricHistoryCard.swift:101`.
- Terms links in an `HStack(spacing: 0)` that cannot wrap — `TermsCheckbox.swift:32-55`.

### E. Fixed sizes around text

- `.frame(width: 80)` on GPA/SAT/ACT fields — `AcademicsSocialTab.swift:109,131`; award year `PublicTab.swift:315`; state `HomeLocationView.swift:53`.
- Clipped wheel pickers — `BasicsTab.swift:340-342`, `AthleticsTab.swift:142-144,157-159`.
- Fixed `frame(height:)` on button labels — `OnboardingStepOneView.swift:259`, `OnboardingStepTwoView.swift:166`, `PushNotificationPrimingView.swift:44`.
- Day number in a fixed 32 pt box in a 7-column grid — `EventsCalendarView.swift:147-153`.
- Nested 200 pt scroller for Quick Tasks — `QuickTaskWidget.swift:61-72`.
- 37 `.font(.system(size:))` uses app-wide; most are icons already scaled with `@ScaledMetric`, but `CoachTagsCard.swift:35-41` (9 pt), `SchoolStatusStepper.swift:144` (12 pt), `PublicProfileCard.swift:209` are not.

## Fix

- Gate screens: wrap in `ScrollView` with the button in `.safeAreaInset(edge: .bottom)`; add `.large` to the sheet detents; compact date picker at accessibility sizes.
- Rows and grids: `@Environment(\.dynamicTypeSize)` → one column / vertical stack when `isAccessibilitySize` (or `ViewThatFits`, or the existing `AdaptiveHStackVStack`).
- Remove `lineLimit` and `minimumScaleFactor` on essential text.
- `minHeight` / `minWidth` / `@ScaledMetric` instead of fixed sizes.

## Done when

Every gate screen's primary button is reachable at the largest accessibility size on the smallest supported iPhone, and the automated audit reports no "Text clipped" items at that size on the audited screens.

## Evidence

Source review, plus the automated audit and screenshots at `UICTContentSizeCategoryAccessibilityXXXL` for the screens listed in section B. Sections A and C–E are not individually verified on device. Severity: **High**; section A items become Blockers if confirmed.

Part of the iOS accessibility audit — tracking issue: TRACKING
