## Problem

Lower-severity items from the audit, grouped so they can be picked off in small PRs.

### Reduce Motion

9 Reduce Motion checks against 34 animation sites. None of the ungated ones is large-scale motion (no carousels, shimmer-in-use or confetti); all are short fades, slides or sweeps:

`ProfileCompletenessCard.swift:95`, `PerformanceDashboardView.swift:103,107`, `CommonWorriesWidget.swift:31,73`, `PhaseCardTaskRow.swift:94`, `RecruitingTimelineView.swift:134`, `DeadlinesListView.swift:144`, `TimelineStatPills.swift:81`, `SchoolCoachingPhilosophySection.swift:71-73`, `SaveStatusView.swift:8`, `PasswordStrengthIndicator.swift:71`, `SignupViewModel.swift:190,194`, `LoginView.swift:48`, `OnboardingContainerView.swift:166`, `HelpSectionDetailView.swift:376`, `ScholarshipCalculatorView.swift:87`, `OffersListView.swift:14,76,128`, `DocumentViewerView.swift:74,79,101,109`, `ImagePreviewView.swift:74`, `EventDetailView.swift:246`. Also `StatusHistoryRow.swift:33` uses a `.relative` date that ticks every second.

Pattern to follow: `AsyncButton.swift:131-140`, `ToastModifier.swift:18`.

### Raw or internal values shown and spoken

- Raw status strings and a 36-character user id: `StatusHistoryRow.swift:16,27,55-57`, `SchoolAttributionSection.swift:59-61,68-69`.
- User-id fragments as names ("Athlete (a1b2c3d4)"): `InteractionFilterBar.swift:164,197,241`, `InteractionActiveFilterChips.swift:60`.
- "Total Storage: Phase 5" placeholder text: `StatisticsCardsRow.swift:26-28`.
- Family code read as a word in Settings: `SettingsView.swift:57-62` (the Family screens use `FamilyUtilities.formatCodeForVoiceOver`).
- Placeholder dashes spoken ("Event: —") and a permanently empty Event tile: `InteractionDetailView.swift:228-234,250-264`.
- Emoji read aloud in headings: `TimelineGuidanceView.swift:25,37,50,58`, `CoachFollowupWidget.swift:54,125`, `DocumentHeaderCard.swift:13`.

### Noise

- Decorative images not hidden, unlabelled spinners, progress views that replace a button's name while loading — lists per area in the audit reports (`SchoolBasicInfoSheet.swift:81-83`, `InboundDraftCard.swift:64-66`, `SaveStatusView.swift:18,26`, `DocumentViewerView.swift:277`, …).
- State spoken twice (label says "selected" and the trait says it again): `PositionChipsView.swift:66-67`, `NotificationToggleChip.swift:9,26-27`, `DateRangeToolbar.swift:27-28,48-49`.
- Field name read twice (visual label + field with the same name are separate stops) across the Player Profile tabs.
- `Toggle` carrying `.isButton`: `AddSchoolView.swift:159-162`, `InteractionAddSchoolSheet.swift:151-154`.
- Dashboard loading skeleton reads "Loading: 0" six times: `DashboardView.swift:398-415`.
- iPad: hidden shortcut buttons with empty titles — `AdaptiveRootView.swift:65-72`.

### Safety

- Discarding a forwarded coach email is immediate and irreversible on a single tap, with no confirmation or undo: `InboundDraftCard.swift:51-57`, `InboundDraftsView.swift:69`, `InboundDraftsViewModel.swift:65-79`. Every other delete in the app confirms first (WCAG 3.3.4).
- Custom back buttons replace the system one on Add School, Add Coach and Log Interaction (`AddSchoolView.swift:82-91`, `AddCoachView.swift:52`, `AddInteractionView.swift:56`); check that the VoiceOver escape gesture still pops, or add `.accessibilityAction(.escape)`.
- The School detail map has `.allowsDirectInteraction`, so a VoiceOver swipe over it moves the map: `SchoolMapView.swift:40-48`.
- Invisible captcha failure gives only "Couldn't verify you're human" in an unannounced banner, with no alternative path: `TurnstileTokenProvider.swift:104-112,164-189`.

### Dead code carrying defects

Not referenced outside their own previews — delete, or fix before reuse: `Features/Tasks/Views/TasksListView.swift` (+ `TaskCard`, `TasksFilterBar`, `TasksProgressCard`, `TaskDetailSection`), `SchoolStatusPickerSection`, `BreakdownRow`, `AutoFilledBadge`, `CoachMetricsSection`, `CoachStatisticsSection`, `ContactInfoSection`, `ContactRow`, `Shared/Components/AppErrorView.swift`, `SessionExpiredSheet.swift`, `CardSkeleton.swift`, `ListRowSkeleton.swift`, `AdaptiveHStackVStack.swift` (worth adopting rather than deleting — see the Larger Text issue), `TimeoutBanner` (no caller passes a reason).

## Evidence

Source review. Severity: **Low**, except the inbound-draft discard (Medium).

Part of the iOS accessibility audit — tracking issue: TRACKING
