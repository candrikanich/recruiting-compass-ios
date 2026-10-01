## Problem

Many tappable controls are smaller than 44×44 pt (project rule and Apple HIG; WCAG 2.5.8 requires 24×24). Three patterns account for nearly all of them.

### A. Full-width "buttons" where only the word is tappable

Sizing and background are applied to the `Button` from outside, so the coloured bar is decoration and only the label text responds:

- `Features/Onboarding/Views/SportGateView.swift:124-142` — "Continue" on a screen that blocks the whole app
- `Features/Family/Views/FamilyManagementParentView.swift:45-59` ("Join Family"), `:96-110` ("Send")
- `Features/Family/Views/FamilyManagementPlayerView.swift:141-155` ("Send")
- `Features/Family/Views/InviteAthleteView.swift:39-55` ("Send Invite")

Fix: move `.frame(maxWidth: .infinity, minHeight: 44)`, padding and background **inside** the label closure, or use `AsyncButton`, which already does this.

### B. Measured by the automated audit ("Hit area is too small")

22 items per run (identical in light and dark):

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

### C. Icon and caption-sized controls with no minimum frame

- Tag remove "x" is a 9 pt glyph with no frame — `Features/Coaches/Components/CoachTagsCard.swift:35-41` (removal is immediate, no confirmation).
- Shared filter chip remove is 24×24 and is the only tappable part of the chip — `Shared/Components/FilterChip.swift:31-39` (15 call sites); "Clear all" is bare text — `FilterChipContainer.swift:42-49`.
- Coach detail: Edit/Delete are 36×36 side by side — `CoachDetailHeader.swift:91-101,107-118,129`; log "Clear", filter menus, small Delete — `CoachInteractionsLogSection.swift:21-22,131-139,283-288`.
- Public profile reorder chevrons (about 12×8 pt, 2 pt apart) — `PublicTab.swift:343-362`; position priority chevrons — `AthleticsTab.swift:357-373`.
- Family Resend/Revoke captions side by side — `FamilyManagementParentView.swift:146-160`, `FamilyManagementPlayerView.swift:191-205`.
- Scatter-chart points are 12 pt tap targets — `ScatterChartView.swift:108-113`.
- Dashboard caption links ("Learn More", "Show N more", "View All Events", …) — `ActionItemCard.swift:49-52`, `ActionItemsWidget.swift:41-51`, `QuickTaskWidget.swift:23-29,45-50`, `UpcomingEventsWidget.swift:51-56,67-78,87-92`, `PerformanceMetricsWidget.swift:38-49`, `SchoolRecommendationsWidget.swift:51-63,109-124`, `GettingStartedChecklistWidget.swift:57-64`.
- Other small targets: `PlayerDetailsView.swift:73-87` (tab pills ≈ 36 pt), `PositionChipsView.swift:55-64`, `HeaderColorPicker.swift:10-17` (32 pt swatches), `SettingsView.swift:65-77,196-210`, `MetricHistoryCard.swift:41-69`, `DeadlinesListView.swift:188-196`, `DocumentFilterBar.swift:20-31,39-51,84-87`, `OfferEditForm.swift:144-153`, `NotificationToggleChip.swift:13-25`, `TemplateEditorView.swift:119-130`, `CommunicationTemplatesView.swift:130-136`, and the per-area lists in the audit reports.

### D. 44 pt frame applied outside the button (needs a device check)

`Button { … }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` grows the layout but probably not the tappable label:

`FavoriteStarButton.swift:8-13`, `ProItem.swift:18-23`, `ConItem.swift:18-24`, `SchoolProsConsSection.swift:44-60,89-105`, `CollegeDataSection.swift:22-36`, `PasswordFormField.swift:52-58`, `GuardianPendingBanner.swift:43-52`, `LegalEmailLink.swift:11-24`, `EmailVerificationBanner.swift:29-35,48-58`, `RecentActivityWidget.swift:23-30,61-71`, `ActivityFeedView.swift:104-111,125-133`, `CoachFollowupWidget.swift:77-84`, `DateRangeToolbar.swift:12-25`, `MetricTypeFilterBar.swift:11-23`, `CoachesPresentSection.swift:52-60`, `InlineErrorView.swift:34-36`.

## Fix

Put `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` on the **label inside** the button — the pattern already used correctly in `SchoolCardView.swift:74-75`, `QuickTaskRow.swift:13-14`, `CoachFollowupRow.swift:59-62`, `CommunicationButton.swift:37`, `Toast.swift:27-31`. Make the whole `FilterChip` the button.

## Done when

The automated audit reports no "Hit area is too small" items on the audited screens, and the section A buttons respond anywhere on the bar.

## Evidence

Section A re-read in source during consolidation. Section B measured on the simulator. Sections C and D come from source review; sizes are inferred from font and padding, and D depends on SwiftUI hit-testing that was not tested. Severity: **High** for A and the tag-remove button; Medium for the rest.

Part of the iOS accessibility audit — tracking issue: TRACKING
