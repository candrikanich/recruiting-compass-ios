# Accessibility findings — Dashboard, ActivityFeed, Analytics, Performance, Timeline, Tasks, Deadlines

Static read of every View/Component file under `Features/{Dashboard,ActivityFeed,Analytics,Performance,Timeline,Tasks,Deadlines}`
plus the shared pieces they use (`Core/Theme/AppColors.swift`, `Shared/Components/{EmptyStateView,LoadingStateView,InlineErrorView}.swift`,
`Features/Auth/Components/Banner.swift`, `Features/Suggestions/Views/SuggestionsListView.swift`).
Line numbers are against the source root in the brief (main checkout). The `a11y-audit` worktree differs in this area only in
`DashboardView.swift` (3 non-UI lines, no line shift), `AdaptiveDashboardGrid.swift` (fold split, +3 lines) and view-model/service files.

Contrast ratios below are computed from the hex values in `AppColors.swift` / system colours (WCAG relative luminance); they are
arithmetic, not measured on device.

Area-wide facts: 0 `AccessibilityNotification` / `UIAccessibility.post`, 0 `@AccessibilityFocusState`, 0 `accessibilityAction`,
1 `accessibilityReduceMotion` check (ScatterChartView) vs 8 animation sites, 2 `accessibilityChartDescriptor` (Performance line chart,
Dashboard interaction-trends bar chart).

Counts: Blocker 2 · High 11 · Medium 13 · Low 8

---

### [Blocker] Expanded timeline phase swallows every task row — tasks cannot be read or completed with VoiceOver
- category: voiceover
- confidence: medium (SwiftUI `.combine` merge semantics; the override of child labels is certain, exact action exposure needs a simulator check)
- where: `Features/Timeline/Components/PhaseCard.swift:98-100` (container), child rows built at `:73-87`
- what: The whole card — header button *and* the expanded `PhaseCardTaskRow` list — is wrapped in
  `.accessibilityElement(children: .combine)` with an explicit `.accessibilityLabel("\(phase.displayLabel), \(completedCount) of \(totalCount) tasks complete")`.
  `.combine` merges all descendant accessibility elements into one, and the explicit label replaces their text, so after expanding
  a phase VoiceOver still exposes a single element reading "Junior Year, 3 of 8 tasks complete".
- user impact: A VoiceOver user cannot hear any task title, status, deadline badge or detail, and cannot target a specific task's
  checkbox (at best the checkboxes surface as custom actions named after their SF Symbol, since the buttons at
  `PhaseCardTaskRow.swift:35-48` have no label). The Timeline's core job — working through tasks — is not doable.
- fix: Move the combine/label/hint onto the header `Button` only (lines 26-71) and add
  `.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")`; leave the `VStack` of task rows as separate elements
  (or wrap the card in `.accessibilityElement(children: .contain)`). Include "Current phase", `phase.theme` and the percent in the header label.

### [Blocker] Performance export share sheet dismisses itself after 0.5 s
- category: timing
- confidence: medium (clear from code; if confirmed it breaks export for every user, not only AT users)
- where: `Features/Performance/Components/ShareSheetView.swift:10-18`, presented from `Features/Performance/Components/ExportFormatSheet.swift:66-68`
- what: The sheet's only content is `ShareLink(item: url) { Label("Share \(filename)", …) }` with
  `.onAppear { Task { try? await Task.sleep(for: .seconds(0.5)); dismiss() } }` — the user has half a second to activate the link.
- user impact: With VoiceOver, Switch Control or Voice Control the link cannot be reached before the sheet closes, so performance
  metrics cannot be exported; there is no way to extend the time limit (WCAG 2.2.1).
- fix: Drop the intermediate sheet and timer: make the "Export CSV/PDF" button in `ExportFormatSheet` itself a `ShareLink(item:)`
  (write the temp file when the format is chosen), or present `ActivityShareSheet` (already in `Shared/Components`) as Analytics does.

---

### [High] Timeline task rows: unlabeled checkbox, hidden badges, details never spoken, no way to choose "complete" vs "expand"
- category: voiceover
- confidence: high (label omissions) / medium (which action double-tap triggers)
- where: `Features/Timeline/Components/PhaseCardTaskRow.swift:35-48, 92-99, 128-141, 161-178`
- what: (a) The checkbox `Button` has only `Image(systemName: task.statusIconName)` — no `accessibilityLabel`. (b) The row is
  `.accessibilityElement(children: .combine)` with an explicit label of `title, category, [Required], status` (`:161-166`); every
  badge is `.accessibilityHidden(true)` (`:140`), so "Locked", "Recovery" and the deadline urgency ("Overdue / Due Soon",
  "Due This Week") are never spoken, and the explicit label also overrides the expanded description / "Why It Matters" /
  "Don't Miss This" text (`:68-82`). (c) The row has both a checkbox button and an `onTapGesture` expander; the hint says
  "Double tap to show details" for expandable rows and nothing tells the user how to mark complete.
- user impact: Even once the Blocker above is fixed, a VoiceOver user can't hear that a task is overdue or locked, can't read its
  detail text, and has no discoverable way to mark an expandable task complete.
- fix: Keep the row as one element but build the label from all visible facts (locked, recovery, deadline urgency), expose state with
  `.accessibilityValue(isExpanded ? … : …)`, put description/why/risk into the label or leave them as separate elements when expanded,
  and add `.accessibilityAction(named: "Mark complete") { onCheckboxTap() }` / `.accessibilityAction(named: "Show details")`.
  Give the checkbox `accessibilityLabel("Mark \(task.title) complete")`.

### [High] Recruiting status (On track / Slightly behind / At risk) is conveyed by colour only
- category: color
- confidence: high
- where: `Features/Timeline/Components/TimelineStatPills.swift:16-35`, `Features/Dashboard/Components/DashboardTimelineSummaryCard.swift:38-46, 101-107`, `Features/Timeline/Models/StatusLabel.swift:4-8` (no display string exists)
- what: `StatusLabel` is rendered only as a tint — `accent: statusColor` on a 12pt icon and the progress bar, and
  `Circle().fill(statusColor).frame(width: 10, height: 10)` on the dashboard card. The VoiceOver strings are
  "Status score \(statusScore) out of 100" with no label either.
- user impact: Colour-blind, Differentiate-Without-Color and VoiceOver users get a bare number and never learn whether the athlete is on track or at risk.
- fix: Add `StatusLabel.displayName` ("On Track", "Slightly Behind", "At Risk"), show it as text beside the score (plus a distinct
  SF Symbol per state), and append it to both accessibility labels.

### [High] Action-item urgency is hidden from VoiceOver
- category: voiceover
- confidence: high
- where: `Features/Dashboard/Components/ActionItemCard.swift:27-41` (also used in `Features/Suggestions/Views/SuggestionsListView.swift:27`)
- what: Both the urgency dot and the visible urgency pill are hidden: `Text(suggestion.urgency.displayName) … .accessibilityHidden(true)`.
  Nothing else on the card speaks "High/Medium/Low".
- user impact: VoiceOver users cannot tell which action items are urgent — the widget's main prioritisation signal.
- fix: Remove `.accessibilityHidden(true)` from the pill and label it `"\(urgency.displayName) priority"`, or group pill + message with
  `.accessibilityElement(children: .combine)`.

### [High] Coach follow-up row: VoiceOver loses the school and "days since contact"; it is also truncated visually
- category: voiceover
- confidence: high
- where: `Features/Dashboard/Components/CoachFollowupRow.swift:12-25`
- what: The profile button contains name + `"\(schoolName) · \(CoachFollowup.daysSinceLabel(…))"` but is overridden with
  `.accessibilityLabel("View \(coach.fullName) profile")`. The second line is also `.lineLimit(1)` (`:20`), so at large text sizes the
  trailing "· 34 days ago" is the part that gets cut.
- user impact: The reason the coach is in this widget (how long since last contact, and which school) is unavailable to VoiceOver users and
  truncated for large-text users.
- fix: Label `"\(coach.fullName), \(schoolName), last contact \(daysSinceLabel)"` with hint "Opens coach profile"; remove `lineLimit(1)`
  (or put the days-since on its own line).

### [High] Deadline rows never speak the date
- category: voiceover
- confidence: high
- where: `Features/Deadlines/Components/DeadlineRow.swift:94-97`
- what: `.accessibilityElement(children: .combine)` + `.accessibilityLabel("\(deadline.label), \(deadline.categoryDisplayName), \(daysUntilLabel)")` —
  `formattedDate` and the "NCAA Calendar" source badge are dropped. Past items read only "…, Past".
- user impact: A VoiceOver user cannot find out what date a deadline falls on (only a relative "12 days"), and for past deadlines gets no date at all.
- fix: Add `formattedDate` (as a spoken long date) and `sourceBadge` to the label; add `.isButton` + hint "Edit deadline" for user deadlines (see Medium finding on row taps).

### [High] Metric history card merges Star / Edit / Delete into one element
- category: voiceover
- confidence: medium (needs simulator: SwiftUI turns merged child buttons into rotor actions and the first one becomes the default activation)
- where: `Features/Performance/Components/MetricHistoryCard.swift:40-70, 108-113`
- what: The card is `.accessibilityElement(children: .combine)` with an explicit label while containing three buttons
  (headline toggle, "Edit", "Delete"), with no `accessibilityAction` replacements and no hint.
- user impact: Edit and Delete are not reachable as buttons; at best they are undiscoverable rotor actions and a plain double-tap toggles
  the headline metric. Voice Control users cannot say "Tap Edit".
- fix: Combine only the text block (title/date/value/verified/notes) and leave the three buttons as their own elements with labels
  `"Edit \(metric.displayName)"`, `"Delete \(metric.displayName)"`; or keep one element and add explicit named `accessibilityAction`s.

### [High] Performance-correlation scatter chart: data points are unreachable without sight and touch
- category: voiceover
- confidence: high
- where: `Features/Analytics/Components/ScatterChartView.swift:58-61, 104-123, 138-169`
- what: Points are `Circle().frame(width: 12, height: 12).onTapGesture { … }.accessibilityHidden(true)` and the whole card is
  `.accessibilityElement(children: .ignore)`; the spoken value is only the min/max of each axis (`:73-80`). There is no
  `accessibilityChartDescriptor`. The per-point detail panel (label, x, y) only appears after tapping a 12pt dot.
- user impact: VoiceOver/Voice Control/Switch users cannot get any individual data point; motor-impaired touch users must hit 12pt targets.
- fix: Rebuild with Swift Charts `PointMark` + `.accessibilityLabel/.accessibilityValue` per mark and an `AXChartDescriptor` (as done in
  `PerformanceChartDescriptor`), or keep the custom drawing and expose each point as an element with label
  `"\(point.label), \(xAxisLabel) \(x), \(yAxisLabel) \(y)"`; enlarge the tap area with `.contentShape(Circle().inset(by: -16))`.

### [High] No async result, toast or error is announced anywhere in this area
- category: voiceover
- confidence: high
- where: `Features/Performance/Views/PerformanceDashboardView.swift:100-110` + `Components/SuccessToast.swift` (2 s toast);
  `Features/Dashboard/Components/DashboardPublicProfileCard.swift:91-109` ("Copied!" for 2 s, label fixed to "Copy public profile link");
  `Features/Dashboard/Components/ParentOnboardingBanner.swift:42-52` ("You're connected!" removed after 3 s);
  `Features/Dashboard/Components/EmailVerificationBanner.swift:42-46` (resend result);
  `Features/Timeline/Views/RecruitingTimelineView.swift:234-240` and `Features/Tasks/Views/TasksListView.swift:54-62, 120-126` ("Great job!");
  `Features/Dashboard/Views/DashboardView.swift:237-242` (error banner appears at the top after an action taken further down);
  `Features/ActivityFeed/Views/ActivityFeedView.swift:104-134` (page change replaces the list, focus stays on "Next" at the bottom)
- what: The area contains zero `AccessibilityNotification.Announcement` / `@AccessibilityFocusState`. Every confirmation is a transient
  visual that appears outside the current VoiceOver focus and (toast, Copied, Connected) disappears in 2–3 s.
- user impact: VoiceOver users get no confirmation that a metric was saved/deleted, a link was copied, a task was completed, a suggestion failed
  to dismiss, or that the page changed (WCAG 4.1.3 Status Messages; 2.2.1 for the auto-dismissing ones).
- fix: Post `AccessibilityNotification.Announcement(message).post()` where each flag is set (view models or `.onChange`), keep toasts on
  screen longer when `UIAccessibility.isVoiceOverRunning`, move focus to the error banner / first row of the new page with
  `@AccessibilityFocusState`, and make the Copy button's label follow its visible state.

### [High] Action-item text is clipped at large text sizes with no way to read the rest
- category: dynamic-type
- confidence: medium (depends on message length; arithmetic at AX sizes suggests ~30 visible characters)
- where: `Features/Dashboard/Components/ActionItemCard.swift:43-47, 82-85`
- what: `Text(suggestion.message) … .lineLimit(3)`; "Learn More" opens generic rule help (`SuggestionHelpModal`), not the message. The CTA is
  `.lineLimit(1).fixedSize(horizontal: true, vertical: false)` next to two 52pt buttons, so at accessibility sizes it overflows the card.
- user impact: At the largest text sizes the suggestion itself ("It's been 30 days since you contacted …") is truncated and cannot be read anywhere.
- fix: Remove the `lineLimit(3)`; wrap `actionRow` in `ViewThatFits` (HStack → VStack) or branch on `dynamicTypeSize.isAccessibilitySize`,
  and drop `fixedSize` on the CTA.

### [High] Fixed 2/3-column grids and side-by-side stat tiles do not reflow at accessibility text sizes
- category: dynamic-type
- confidence: medium (layout arithmetic; needs AX5 simulator pass)
- where: `Features/Performance/Views/PerformanceDashboardView.swift:239-243` (3 columns of `.title` values in ~100pt cells) with `Components/LatestMetricCard.swift:13-24`;
  `Features/Timeline/Components/TimelineStatPills.swift:26-56` (3 tiles in an `HStack`);
  `Features/Dashboard/Components/DashboardStatsCardsSection.swift:12` + `StatCard.swift:17-31` (icon + `.largeTitle` count in half width);
  `Features/Dashboard/Components/AtAGlanceSummary.swift:16-19` + `MetricCard.swift:10-20` (`lineLimit(1)`, `minimumScaleFactor(0.7)`, title `lineLimit(2)`);
  `Features/Analytics/Views/AnalyticsDashboardView.swift:201-204`;
  `Features/Analytics/Components/PieChartView.swift:21-27, 92-95` (160pt ring beside a legend whose labels are `lineLimit(1)`);
  `Features/Dashboard/Components/SchoolRecommendationsWidget.swift:73-75, 97-100, 130` (fixed 180pt cards, name/reason `lineLimit(2)`)
- what: Column counts and widths are constant regardless of `dynamicTypeSize`; there is no `ViewThatFits` or accessibility-size branch anywhere in the area.
- user impact: At AX sizes values and titles break mid-word, shrink, or truncate ("Interactions This Month", pie legend labels, recommendation reasons).
- fix: `@Environment(\.dynamicTypeSize)` → one column when `isAccessibilitySize` (grids), `ViewThatFits`/`AnyLayout` for the HStack cases,
  stack the pie legend under the ring, remove `lineLimit(1)` on legend labels, let recommendation cards grow.

### [High] Dark mode: white CTA text on amber for medium-urgency action items (~1.6:1)
- category: dark-mode
- confidence: high (computed)
- where: `Features/Dashboard/Components/ActionItemCard.swift:88-89`, colour from `Features/Dashboard/Models/Suggestion.swift:22-28`, `Core/Theme/AppColors.swift:85`
- what: `.background(suggestion.urgency.color).foregroundStyle(Color.white)`; `amberGold` is adaptive and becomes `#fbbf24` in dark mode
  (designed as a text colour), so white-on-amber is about 1.6:1. Light mode (`#b45309`) is fine at 5.0:1.
- user impact: In dark mode the primary button label of every medium-urgency action item is effectively unreadable.
- fix: Use a fill token that stays dark in both schemes (e.g. `Color(hex: "b45309")` / a new `Surface.warningCTA`-style token with ≥4.5:1 against white), or switch the label to a dark foreground in dark mode.

---

### [Medium] Expanded/collapsed state is not exposed
- category: voiceover
- confidence: high
- where: `Features/Timeline/Components/CollapsibleSection.swift:15-25`; `Features/Timeline/Components/CommonWorriesWidget.swift:53-66`;
  `Features/Timeline/Components/PhaseCard.swift:26-71, 99-100`; `Features/Deadlines/Views/DeadlinesListView.swift:143-153` (hint only);
  `Features/Tasks/Components/TaskCard.swift:96-113`
- what: Disclosure buttons show state only through a chevron image (`Image(systemName: isExpanded ? "chevron.up" : "chevron.down")`); no
  `accessibilityValue`, and the hint is the static "Double tap to expand or collapse".
- user impact: VoiceOver users can't tell whether a section is open, and after toggling nothing confirms the change.
- fix: `.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")` on each toggle and hide the chevron (`.accessibilityHidden(true)`).

### [Medium] Section and screen titles missing the header trait
- category: voiceover
- confidence: high
- where: `Features/Performance/Views/PerformanceDashboardView.swift:182, 212, 235, 260`; `Features/Performance/Components/MetricFormView.swift:53`;
  `Features/Performance/Components/ExportFormatSheet.swift:25`; `Features/Dashboard/Components/DashboardPublicProfileCard.swift:60`;
  `Features/Dashboard/Components/SuggestionHelpModal.swift:75-77`; `Features/Timeline/Views/RecruitingTimelineView.swift:66`;
  `Features/Tasks/Views/TasksListView.swift:35`; `Features/Deadlines/Views/DeadlinesListView.swift:241`;
  chart titles in `Features/Analytics/Components/PieChartView.swift:13-16`, `FunnelChartView.swift:13-16`, `ScatterChartView.swift:31-34`
  (trait is set but discarded by the card-level `.accessibilityElement(children: .ignore)`)
- what: e.g. `Text("Metric History").font(.title3).bold()` with no `.accessibilityAddTraits(.isHeader)`.
- user impact: The headings rotor skips most of Performance, Analytics and Timeline, so long screens must be swiped linearly.
- fix: Add `.accessibilityAddTraits(.isHeader)`; for the chart cards add the trait to the combined element or keep the title outside the ignored group.
  Also remove the wrong header trait on the subtitle at `Features/Analytics/Views/AnalyticsDashboardView.swift:190-193`.

### [Medium] Accessibility labels that drop, replace or mangle visible information
- category: voiceover
- confidence: high
- where / what:
  - `Features/Dashboard/Components/EventRow.swift:89-91` — label is `"\(event.type): \(event.name)"`: raw DB value ("official_visit") is spoken and `event.location` is dropped.
  - `Features/Dashboard/Views/MoreMenuView.swift:125` — outer `NavigationLink` label `section.title` overrides the row label at `:173`, so the description and the "N unread" notification count are never spoken.
  - `Features/Performance/Components/MetricFormView.swift:121-127` — fixed-unit `Text(formState.unit)` gets `.accessibilityLabel("Unit of measurement")`, replacing the unit itself ("mph").
  - `Features/Performance/Components/TrendCard.swift:26-27` — label omits the visible min–max range.
  - `Features/Dashboard/Components/DashboardPublicProfileCard.swift:79-88` — the URL text is replaced by "Public profile link".
  - `Features/Tasks/Components/TasksParentBanner.swift:47-48` (shown on Timeline via `RecruitingTimelineView.swift:160`) — `.combine` + label merges the "Exit preview mode" button into a static-sounding banner; `ParentPreviewBanner.swift:47` correctly uses `.contain`.
  - `Features/Auth/Components/Banner.swift:69-70` (used by `DashboardView.swift:423`, `PerformanceDashboardView.swift:14`) — same pattern: `.combine` + label swallows the "Close message" button. (Outside this area; cross-reference for the Auth/shared reviewer.)
  - `Features/Deadlines/Components/DeadlinesCalendarGridView.swift:68-72` — day label is the raw ISO string ("2026-10-01"), English-only pluralisation, no weekday.
  - `Features/Dashboard/Components/CoachFollowupWidget.swift:38` — bare count badge reads "3" with no context.
- user impact: VoiceOver users miss event locations, unread counts, units and ranges that sighted users see, and hear raw identifiers.
- fix: Build labels from the same data the row shows (use `accessibilityValue` for the changing part); put label/value on the unit `Text` as
  label "Unit" + value; use `.contain` for banners with a button; format calendar days with `Date.formatted(date: .complete, time: .omitted)`.

### [Medium] Voice Control: spoken label does not match the visible text
- category: voice-control
- confidence: high
- where (visible → label):
  - `Features/Dashboard/Components/ActionItemCard.swift:96-103` — "Done" → "Complete suggestion"
  - `Features/Dashboard/Components/SchoolRecommendationsWidget.swift:117-126` — "Skip" → "Dismiss \(name)"
  - `Features/Dashboard/Components/GettingStartedChecklistWidget.swift:57-65` — "I'm good for now" → "Dismiss getting started checklist"
  - `Features/Dashboard/Components/ActionItemsWidget.swift:41-52` — "Show N more" → "View all action items"
  - `Features/Dashboard/Components/PerformanceMetricsWidget.swift:38-52` and `UpcomingEventsWidget.swift:67-81` — "Show less" / "Show N more …" → "Show fewer …" / "Show all N …"
  - `Features/Dashboard/Components/DashboardPublicProfileCard.swift:102, 109` — "Copy link" / "Copied!" → "Copy public profile link"
  - `Features/Dashboard/Components/DashboardTimelineSummaryCard.swift:50-63, 72-74` — the visible "Timeline" button is merged into a card whose name is the long status sentence
  - `Features/Performance/Components/MetricFormView.swift:97-99` — "Date" → "Recording date"; `:71` "Metric type selector" (control type in the label)
- what: No `accessibilityInputLabels` anywhere in the area.
- user impact: "Tap Done", "Tap Skip", "Tap Timeline" etc. do nothing; users fall back to number overlays.
- fix: Start each label with the visible text ("Done, complete suggestion") or add `.accessibilityInputLabels(["Done", …])`.

### [Medium] Tap targets below 44×44pt
- category: hit-target
- confidence: high for the unpadded text buttons; medium for the "frame outside the button" cases
- where:
  - Unpadded caption/subheadline text buttons (≈16–22pt tall): `ActionItemCard.swift:49-52` (Learn More), `ActionItemsWidget.swift:41-51`,
    `QuickTaskWidget.swift:23-29, 45-50`, `UpcomingEventsWidget.swift:51-56, 67-78, 87-92`, `PerformanceMetricsWidget.swift:38-49`,
    `SchoolRecommendationsWidget.swift:51-63`, `GettingStartedChecklistWidget.swift:57-64`, `RecruitingCalendarWidget.swift:239-240` (caption2 link),
    `ParentOnboardingBanner.swift:77-95` (≈30pt CTA + ≈16pt "Family Management" link), `DashboardTimelineSummaryCard.swift:50-61` (caption + 4pt padding),
    `Timeline/Components/WhatMattersNowWidget.swift:23-37`, `Timeline/Components/CollapsibleSection.swift:15-24`
  - Small padded chips/buttons (≈28–32pt): `Performance/Components/MetricHistoryCard.swift:41-69`, `SchoolRecommendationsWidget.swift:109-124` (`minHeight: 32`),
    `Deadlines/Views/DeadlinesListView.swift:188-196` (category chips), `ActionItemCard.swift:83-90`
  - `.frame(minWidth: 44, minHeight: 44)` applied to the `Button`, not its label, so the tappable region is probably still the glyph:
    `EmailVerificationBanner.swift:29-35, 48-58`, `ActivityFeed/Components/RecentActivityWidget.swift:23-30, 61-71`,
    `ActivityFeed/Views/ActivityFeedView.swift:104-111, 125-133`, `CoachFollowupWidget.swift:77-84`,
    `Analytics/Components/ScatterChartView.swift:152-160`, `DateRangeToolbar.swift:12-25`, `MetricTypeFilterBar.swift:11-23`
  - 12pt scatter points (`ScatterChartView.swift:108-113`)
- user impact: Small targets are hard to hit for users with motor impairments; several sit next to each other (Edit/Delete).
- fix: Put `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` inside the button label (as `QuickTaskRow`, `CoachFollowupRow.iconAction` and
  `ActionItemCard.iconLabelButton` already do).

### [Medium] Light-mode contrast failures (small text on tints / brand colours)
- category: color
- confidence: medium (computed from hex; verify on device with Increase Contrast off)
- where:
  - `Color.successGreen`/`primaryGreen` = `#059669` as small text ≈ 3.8:1 on white: `LatestMetricCard.swift:31-33`, `MetricHistoryCard.swift:88-91`,
    `PhaseCard.swift:108-110` (caption2 on green tint ≈ 3.1:1), `RecruitingTimelineView.swift:235-237`, `ProfileCompletenessCard.swift:97-99`
  - Amber `F59E0B` text ≈ 2.2:1: `DashboardTimelineSummaryCard.swift:22, 30-35` (Senior badge), `Tasks/Models/TaskDeadlineUrgency.swift:34` → "Due This Week" badge in `PhaseCardTaskRow.swift:112`,
    `Tasks/Models/TaskWithStatus.swift:30` (in-progress status)
  - System `.orange`/`.green`/`.gray`/`.blue`/`.purple` caption text on 15 % tint (≈2.0–3.7:1): `Deadlines/Components/DeadlineRow.swift:85-91`, `PhaseCardTaskRow.swift:106`
  - Category badges `orange600` (3.6:1), `emerald600` (3.8:1), `pink500` (3.1:1) at caption2: `Tasks/Models/TaskCategoryDisplay.swift:17-25` via `PhaseCardTaskRow.swift:114`
  - White on 500-level fills (2.5–3.8:1): `Analytics/Components/FunnelChartView.swift:72-78` (`AnalyticsChartColors.funnelPalette`), `Performance/Components/SuccessToast.swift:10-13` (3.8:1),
    `ParentOnboardingBanner.swift:80-86, 99-105` (white on `#D97706` ≈ 3.2:1; ≈ 2.2:1 in dark), `MoreMenuView.swift:155-162` (white on system red ≈ 3.6:1)
  - `Performance/Components/TrendIndicator.swift:18-31` — gray on systemGray5 ≈ 2.6:1, green/red on own tint ≈ 3.1/3.9:1
  - `.foregroundStyle(.tertiary)` for the recorded date: `LatestMetricCard.swift:26-28`
  - `Color.secondaryText` (`#64748b`) on `Surface.muted` ≈ 4.0:1: `Timeline/Components/UpcomingMilestonesWidget.swift:69-80, 91`
- user impact: Status badges, "Verified", trend pills and funnel values are hard to read for low-vision users; blocks the Sufficient Contrast label.
- fix: Use the 700-level tokens for text (`emerald700` 5.5:1, `orange700` 5.2:1, `amberGold`), darken fills under white text (600/700 level), replace `.tertiary` with `.secondary`.

### [Medium] Dark mode: non-adaptive brand colours used as text
- category: dark-mode
- confidence: medium (computed)
- where: `Color.accentBlue` (`#2563eb`, ≈ 3.2:1 on `Surface.card` dark `#1E1E1E`) for caption links/values throughout — e.g. `ActionItemCard.swift:51`, `ActionItemsWidget.swift:49`,
  `UpcomingEventsWidget.swift:54, 77, 90`, `PerformanceMetricsWidget.swift:48`, `GettingStartedChecklistWidget.swift:170-175`, `RecentActivityWidget.swift:28, 69`,
  `MetricCard.swift:12` (via `AtAGlanceSummary`), `LatestMetricCard.swift:17`, `SchoolRecommendationsWidget.swift:61, 85`, `DashboardTimelineSummaryCard.swift:57`;
  `Color.errorRed` (`#dc2626`, ≈ 3.5:1) — `QuickTaskRow.swift:30`, `MetricHistoryCard.swift:68`, `ActivityFeedView.swift:200`;
  `ProfileCompletenessCard.swift:105-109` (ring text `Brand.blue600`);
  cosmetic: `Analytics/Components/PieChartView.swift:65-67` (donut hole `Color(.systemBackground)` = black on a `#1E1E1E` card),
  `DashboardView.swift:408` (slate100 skeleton cards stay bright in dark mode)
- what: `accentBlue`, `errorRed`, `successGreen` are single-value tokens (`AppColors.swift:75, 78, 86`) while `darkSlate`, `secondaryText`, `amberGold` are adaptive.
- user impact: Link-style buttons and blue stat values drop below AA in dark mode.
- fix: Make these tokens adaptive like `amberGold` (e.g. dark `blue-400 #60a5fa`, `red-400`, `emerald-400`) — one change in `AppColors.swift`.
  Note the knock-on: once adaptive, they can no longer be used as *fills* under white text (see the amber CTA finding).

### [Medium] Pie and funnel charts are a single read-only blob (no Audio Graph, legend maps by colour only)
- category: voiceover
- confidence: high
- where: `Features/Analytics/Components/PieChartView.swift:30-33, 84-104`; `Features/Analytics/Components/FunnelChartView.swift:32-35`
- what: Each card is `.accessibilityElement(children: .ignore)` with one long `accessibilityValue` listing every segment ("Email: 12 (40%); …"). All values are
  present, but it is one unnavigable string with no `accessibilityChartDescriptor`. Visually, slices are tied to legend rows only by a 10pt colour dot.
- user impact: Usable but tedious with VoiceOver (no per-segment navigation or audio graph); colour-blind users cannot match slices to legend entries.
- fix: Rebuild with Swift Charts `SectorMark`/`BarMark` (per-mark labels + free Audio Graph) or add an `AXChartDescriptor` with a categorical axis, as PR #206
  did for `PerformanceChartView` and as `InteractionTrendsChartDescriptor` does. Order the legend to match slice order and add the percentage; under
  `accessibilityDifferentiateWithoutColor` add direct slice labels or patterns.
- note (PR #206 follow-up): Audio Graphs exist for `PerformanceChartView` and `InteractionTrendsChart` only. Not covered: `PieChartView` (×3 uses),
  `FunnelChartView`, `ScatterChartView`, and `MiniBarChart` (hidden; its `TrendCard` label carries trend/count/average).

### [Medium] Deadlines: editable rows are plain tap gestures; calendar categories are colour dots
- category: voiceover
- confidence: medium
- where: `Features/Deadlines/Views/DeadlinesListView.swift:208-224`; `Features/Deadlines/Components/DeadlinesCalendarGridView.swift:50-57`
- what: `DeadlineRow(...).contentShape(Rectangle()).onTapGesture { deadlineToEdit = … }` — no `.isButton` trait or hint, and NCAA rows look identical but do nothing.
  Calendar day cells show up to three 5pt category-coloured dots; the label gives only a count. (Swipe-to-delete in the `List` is exposed automatically as a VoiceOver action — fine.)
- user impact: VoiceOver/Voice Control users are not told that their own deadlines can be opened for editing; the dots carry category by colour alone.
- fix: Wrap user rows in a `Button` (or add `.accessibilityAddTraits(.isButton)` + hint "Edit deadline" + `.accessibilityAction(named: "Remove")`), and include category names in the day label.

### [Medium] Forms: save errors appear behind the sheet; disabled Save with no explanation
- category: forms
- confidence: medium
- where: `Features/Performance/Components/MetricFormView.swift:147-155` + `ViewModels/PerformanceDashboardViewModel.swift` `addMetric()` catch (sets `errorMessage`, rendered by the
  `ErrorBanner` at `PerformanceDashboardView.swift:13-16`, i.e. under the presented sheet); `Features/Deadlines/Views/AddDeadlineSheet.swift:50-52, 95-106`
  (failure "surfaces via the list view's error alert" while the sheet is still up; silent disable when the label exceeds 200 characters);
  `Features/Dashboard/Components/QuickTaskWidget.swift:36-40` (placeholder-only field)
- what: Required fields are not marked, invalid input (non-numeric value, missing type) just leaves the submit button disabled, and server failures are reported on the screen behind the form.
- user impact: Users — especially with VoiceOver — get no feedback on why they cannot save or that a save failed.
- fix: Show an inline error inside the sheet (and announce it / move focus with `@AccessibilityFocusState`), mark required fields ("Value, required"), show a character-count/limit message.

### [Medium] Content truncated with `lineLimit` and no alternative
- category: dynamic-type
- confidence: medium
- where: `Features/ActivityFeed/Components/ActivityEventItem.swift:33, 39` (title 1 line, description 2 lines; document-upload rows are not tappable and interaction rows open the school, not the interaction);
  `Features/Dashboard/Components/DashboardTimelineSummaryCard.swift:84, 89` (top-priority task and reason, 1 line each, inside an HStack-heavy card that cannot reflow);
  `Features/Timeline/Components/WhatMattersNowWidget.swift:33`; `Features/Performance/Components/MetricHistoryCard.swift:101` (notes, 3 lines);
  non-reflowing rows: `ActivityEventItem.swift:15-58` (text squeezed between icon and a trailing time column), `Deadlines/Components/DeadlineRow.swift:58-92`,
  `MetricHistoryCard.swift:17-71` (title beside three buttons), `ParentOnboardingBanner.swift:57-109`
- user impact: At large text sizes activity titles, priorities and notes are cut to a few words.
- fix: Remove the limits (or raise them when `dynamicTypeSize.isAccessibilitySize`) and use `ViewThatFits` to drop trailing columns below the text.

### [Medium] Profile ring percentage does not scale with its container
- category: dynamic-type
- confidence: medium
- where: `Features/Dashboard/Components/ProfileCompletenessCard.swift:97-101`
- what: `Text("\(Int(percentage * 100))%").font(.caption.bold())` inside `.frame(width: 56, height: 56)` with a 6pt stroke; the ring is also the only place the number is shown in the expanded card.
- user impact: At accessibility sizes the percentage overflows or collides with the ring.
- fix: `@ScaledMetric` for the ring diameter, or move the percentage into the adjacent text column.

### [Medium] Nested scroll region in Quick Tasks
- category: dynamic-type
- confidence: medium
- where: `Features/Dashboard/Components/QuickTaskWidget.swift:61-72`
- what: `ScrollView { … }.frame(maxHeight: 200)` inside the dashboard `ScrollView`; rows are 44pt+ and grow with text size.
- user impact: At large text sizes only one or two tasks are visible in a small inner scroller that is easy to miss and awkward with VoiceOver three-finger scrolling.
- fix: Drop the inner `ScrollView` (show first N with "Show all") or scale the max height with `@ScaledMetric`.

### [Medium] Timeline: jumping from Guidance to a task does not move focus
- category: voiceover
- confidence: medium
- where: `Features/Timeline/Views/RecruitingTimelineView.swift:46-55, 129-138`
- what: Selecting a "What Matters Right Now" item switches the segmented tab, expands a phase and animates a scroll 350 ms later; VoiceOver focus is not moved and nothing is announced.
- user impact: VoiceOver users activate a priority and are left on a now-removed element with no indication of what changed.
- fix: `@AccessibilityFocusState` bound to the phase card (or the task row) set after the scroll; gate the `withAnimation` on Reduce Motion.

---

### [Low] Animations not gated on Reduce Motion
- category: motion
- confidence: high
- where: `Features/Dashboard/Components/ProfileCompletenessCard.swift:95` (0.5 s ring sweep); `Features/Performance/Views/PerformanceDashboardView.swift:103, 107` (toast slide);
  `Features/Timeline/Components/CommonWorriesWidget.swift:31, 73` (move transition); `Features/Timeline/Components/PhaseCardTaskRow.swift:94`;
  `Features/Timeline/Views/RecruitingTimelineView.swift:134` (animated scroll); `Features/Deadlines/Views/DeadlinesListView.swift:144`;
  `Features/Timeline/Components/TimelineStatPills.swift:81` (`contentTransition(.numericText())`)
- what: Only `ScatterChartView.swift:114-120` checks `accessibilityReduceMotion`.
- user impact: Minor slides/sweeps still play with Reduce Motion on.
- fix: `@Environment(\.accessibilityReduceMotion)`; use `.opacity` transitions / `withAnimation(reduceMotion ? nil : …)`.

### [Low] Emoji and decorative glyphs read aloud
- category: voiceover
- confidence: medium
- where: `Features/Timeline/Views/TimelineGuidanceView.swift:25, 37, 50, 58` ("⚡ What Matters Right Now" …); `Features/Dashboard/Components/CoachFollowupWidget.swift:54, 125`;
  `Features/Timeline/Components/WhatNotToStressWidget.swift:22` (`Text(item.icon)` not hidden); chevrons inside buttons at `CollapsibleSection.swift:20`, `CommonWorriesWidget.swift:60`;
  `Features/Performance/Components/ExportFormatSheet.swift:19-22` (decorative share glyph is a focusable image)
- fix: Give those elements an explicit `accessibilityLabel` without the emoji, and `.accessibilityHidden(true)` on the glyphs.

### [Low] Redundant or noisy hints/values
- category: voiceover
- confidence: high
- where: "Currently selected" hint alongside `.isSelected` — `Analytics/Components/DateRangeToolbar.swift:27-28, 48-49`, `Performance/Components/MetricTypeFilterBar.swift:25-26`;
  "Double tap to …" hints — `AthleteRow.swift:41`, `QuickTaskRow.swift:19`, `TasksFilterBar.swift:17, 26`, `AnalyticsDashboardView.swift:235`;
  `AthleteRow.swift:40` uses value "Selected/Not selected" instead of the `.isSelected` trait;
  `Analytics/Components/StatCardView.swift:35-36` speaks the trend twice (in label and as value);
  `StatCard.swift:65-69` adds its own label/trait/hint inside the labelled `Button` in `DashboardStatsCardsSection.swift`
- fix: Use the trait only; phrase hints as outcomes ("Selects this athlete").

### [Low] Loading placeholders are unlabelled or repeated
- category: voiceover
- confidence: medium
- where: `Features/Dashboard/Views/DashboardView.swift:398-415` (six redacted cards each read "Loading: 0"); `Features/ActivityFeed/Components/RecentActivityWidget.swift:38-40`;
  `Features/Dashboard/Components/DashboardPublicProfileCard.swift:66-71`; `Features/Dashboard/Components/EmailVerificationBanner.swift:49-50`
- fix: One combined element labelled "Loading dashboard"; label the spinners.

### [Low] Month navigation and day selection in the deadline calendar give no feedback
- category: voiceover
- confidence: medium
- where: `Features/Deadlines/Views/DeadlinesListView.swift:232-272`
- what: Changing month or selecting a day updates the title / reveals a list below the grid silently.
- fix: Announce the new month title; after selecting a day, announce "N deadlines" or move focus to the list.

### [Low] Past-deadline and "Great job" emphasis rely on tint
- category: color
- confidence: low
- where: `Features/Deadlines/Components/DeadlineRow.swift:87-90`; `Features/Tasks/Components/TaskDetailSection.swift:38-41`
- what: Both also carry text ("Past", "Complete These First"), so this is only a contrast/polish note.
- fix: None required beyond the contrast fixes above.

### [Low] Analytics/Performance metric hint keyed on English titles
- category: voiceover
- confidence: high
- where: `Features/Dashboard/Components/MetricCard.swift:31-42`
- what: `switch title { case "Days Until Graduation": … }` — hints disappear if titles are ever localised/reworded.
- fix: Pass the hint in as a parameter.

### [Low] Unreachable Tasks screen carries its own defects
- category: voiceover
- confidence: high (that it is unreachable: `TasksListView(` is referenced only by its own `#Preview`)
- where: `Features/Tasks/Views/TasksListView.swift`, `Features/Tasks/Components/TaskCard.swift:101-113`, `TasksFilterBar.swift`, `TasksProgressCard.swift`, `TaskDetailSection.swift`
- what: If revived: `TaskCard` has the same `.combine` + explicit label problem as `PhaseCard` (checkbox merged, hint says "expand or collapse", expanded
  "Why It Matters / What Can Go Wrong / Complete These First" never spoken), a 3 s auto-dismissing success message, and a header without `.isHeader`.
- fix: Delete the dead screen or fix alongside `PhaseCardTaskRow`.

---

## Done well
- `PerformanceChartView` + `PerformanceChartDescriptor` (PR #206) and `InteractionTrendsChart` + `InteractionTrendsChartDescriptor`: real Audio Graphs with per-point labels and units.
- Widget titles on the dashboard consistently carry `.isHeader` (Action Items, Coaches Needing Follow-up, Upcoming Events, Quick Tasks, At a Glance, Recruiting Calendar, Performance Metrics, Interaction Trends, Recent Activity, Getting Started, Recommended Schools).
- Decorative icons are almost always `.accessibilityHidden(true)`; icon-only buttons are labelled (`QuickTaskRow`, `CoachFollowupRow.iconAction`, `ParentPreviewBanner`, toolbar buttons in Deadlines/Performance/Analytics).
- Correct 44pt targets where the frame is inside the label: `QuickTaskRow.swift:13-14, 31-32`, `CoachFollowupRow.swift:59-62`, `ActionItemCard.swift:130-131`, `PhaseCardTaskRow.swift:45-46`, `ParentPreviewBanner.swift:32-33`, Deadlines toolbar and calendar cells.
- Selected state via `.isSelected`: `DateRangeToolbar`, `MetricTypeFilterBar`, `FormatOptionCard`, Deadlines category chips and calendar days.
- Status is usually paired with a shape or text, not colour alone: `TaskWithStatus.statusIconName`, `TaskDeadlineUrgency.iconName`, `TrendIndicator` (arrow + word), `StatCardView` trend arrows, checklist rows (icon + strikethrough + value).
- Progress is spoken: Getting Started (`ProgressView` label + percent value), `ProfileCompletenessCard`, `TasksProgressCard`, `TimelineStatPills` tasks/milestones.
- Semantic fonts throughout; the five `.font(.system(size:))` uses are all on icons and are scaled (`@ScaledMetric` or a size-category branch).
- Adaptive text/surface tokens (`darkSlate`, `secondaryText`, `amberGold`, `Surface.*`, banner colours) and system backgrounds — no hard-coded white/black page backgrounds; white-on-gradient stat cards use 600–800 level colours (≥ 5:1).
- `LoadingStateView`, `EmptyStateView`, `InlineErrorView` and `ContentUnavailableView` give labelled loading/empty/error states with a retry action.
- `ActivityEventItem` builds a complete label (type, title, description, relative time) and scales its icon bubble for accessibility sizes.
- `ScatterChartView` gates its selection animation on Reduce Motion.

## Needs simulator verification
- Exact VoiceOver behaviour of `.accessibilityElement(children: .combine)` containers that hold buttons: `PhaseCard`, `PhaseCardTaskRow`, `MetricHistoryCard`,
  `TasksParentBanner`, `Banner`, `DashboardTimelineSummaryCard` — which child becomes the default activation and how the rest appear in the Actions rotor.
- `ShareSheetView` 0.5 s auto-dismiss: confirm whether Performance export works at all (with and without VoiceOver).
- Whether `.frame(minWidth: 44, minHeight: 44)` applied outside a default-style `Button` enlarges the tap area (listed under hit targets).
- `SuggestionsListView`: `ActionItemCard` inside a `List` row has two default-style buttons ("Learn More" and the CTA); SwiftUI may fire both on a row tap.
- Full pass at AX5 on iPhone SE/mini width for: dashboard stat grid, At a Glance, Latest Metrics (3 columns), Timeline stat pills, pie chart + legend,
  `ActionItemCard` action row, `MetricHistoryCard` header, `DeadlineRow`, `ParentOnboardingBanner`, `ActivityEventItem`, segmented pickers (Activity date range, Timeline tabs).
- All computed contrast ratios, in light and dark, plus Increase Contrast; especially amber CTA in dark mode, `accentBlue` links on dark cards, funnel labels, deadline day badges.
- What VoiceOver reads for `Text` containing emoji section titles and for SF Symbol images left inside button labels.
- `AddDeadlineSheet` / `MetricFormView` failure path: is any error visible or spoken while the sheet is open?
- Nested vertical `ScrollView` in `TimelineGuidanceView.swift:22` inside the timeline's `ScrollView` — check VoiceOver scrolling and focus order.
- Smart Invert / Differentiate Without Color rendering of the pie chart and deadline calendar dots.
