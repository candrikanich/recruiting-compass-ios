## Problem

Results, confirmations and errors are almost never announced to VoiceOver, and many of them disappear after 2–3 seconds. The app has an `AccessibilityAnnouncing` protocol (`Core/Protocols/AccessibilityAnnouncing.swift`) but only the Add School / Add Coach flows and `EmailVerificationView` use it. WCAG 4.1.3 (Status Messages) and 2.2.1 (Timing Adjustable).

### Shared root causes (fix these first — each covers many screens)

- **Toast** — `Shared/Components/ToastModifier.swift:19-24`, `Toast.swift:39-41`. Appears, sleeps `duration` (default 3 s), removes itself; posts no announcement. 12 call sites on 10 screens (Offers, Interactions, Coaches, Quick Communication, Invite Join, Family Management, Invite Athlete, Coach Emails, School detail, Schools list).
- **Autosave status** — `Shared/Components/SaveStatusView.swift:16-31`. "Saving…/Saved" are silent. 7 screens (`SchoolDetailView:52`, `CoachDetailView:77`, `PlayerDetailsView:37`, `HomeLocationView:145`, `NotificationPreferencesView:144`, `SchoolPreferencesView:109`, `DashboardCustomizationView:170`).
- **Form error summary** — `Shared/Components/Forms/FormErrorSummary.swift:59-67`. The announcement is in `.onChange(of: errors)` inside `if !errors.isEmpty`, so the first failed submit is silent.

### Auth (first-run path)

- Login / signup / forgot / reset failures only set `errorMessage`; nothing is announced and focus does not move. On signup the banner is at the top of a long scroll view while the button is at the bottom. `Features/Auth/Views/LoginView.swift:118-126`, `SignupView.swift:252-264`, `ForgotPasswordView.swift:39-43,84-90,157-163`, `ResetPasswordView.swift:69-78`.
- Password-reset success auto-dismisses after **3 seconds** with no announcement: `ResetPasswordView.swift:58-62,192-229`, `Features/Auth/Configuration/PasswordResetConfig.swift:10` (`successCountdownDuration: 3`).
- Email-verification screen flips between "pending" and "checking" on every poll: `Features/Auth/ViewModels/EmailVerificationViewModel.swift:160-167`.

### Errors that are never shown at all (affects every user)

- **Coach detail** — `Features/Coaches/Views/CoachDetailView.swift:58-64` renders `errorMessage` only when the coach has not loaded. After load, "Failed to save tags/notes/changes", "Failed to delete interaction", "Failed to delete coach" (`CoachDetailViewModel.swift:281,304,380,458,504,509,543,547`) are set and never displayed. `CoachEditForm` has no error slot.
- **Interaction detail** — a failed delete only fires a haptic (`InteractionDetailView.swift:37-42,91-97`).
- **Performance add metric / Add Deadline** — save failures are reported on the screen behind the open sheet (`Features/Performance/Components/MetricFormView.swift:147-155`, `Features/Deadlines/Views/AddDeadlineSheet.swift:50-52,95-106`).

### Other silent or short-lived messages

- Quick Communication send warnings ("…Tap Send again to send anyway.") appear away from focus: `Features/Coaches/Views/QuickCommunicationView.swift:283-288,296-306,46-55,336-340,351-355`.
- Profile "Saved!" / "Password updated!" shown for 2 s then cleared: `Features/Profile/ViewModels/ProfileViewModel.swift:211-213,261-263`; inline results at `ProfileView.swift:122-126,171-176,239-244,303-315,391-396`.
- Event detail hand-rolled 2 s toast: `Features/Events/Views/EventDetailView.swift:90-94,234-249`.
- Performance 2 s `SuccessToast`; dashboard "Copied!" (2 s), "You're connected!" (3 s), "Great job!": `PerformanceDashboardView.swift:100-110`, `DashboardPublicProfileCard.swift:91-109`, `ParentOnboardingBanner.swift:42-52`, `RecruitingTimelineView.swift:234-240`.
- Create Event validation errors are drawn as overlays on the field and never announced: `Features/Events/Views/CreateEventView.swift:109-111,116-118,143-145,186-188,224-226,392-400`.
- Document upload progress and errors: `Features/Documents/Components/DocumentUploadSheet.swift:76-96`.
- Copy actions with no feedback at all: `Features/Family/Views/InviteAthleteView.swift:87-94`, `Features/PublicProfile/Components/ShareLinkRow.swift:15-18`.
- School detail lookup/enrich errors, status changes and filter result counts: `CollegeDataSection.swift:40-51`, `AcademicFitCard.swift:36-38`, `SchoolsListView.swift:152-156`.
- Secondary flows: `GuardianClaimView.swift:18-30,64-68`, `GuardianPendingBanner.swift:37-41`, `SportGateView.swift:117-121`, `AboutView.swift:40-55`, `HelpFeedbackView.swift:55-68`, `PlanView.swift:20-23`.

## Fix

1. `ToastModifier`: post `AccessibilityNotification.Announcement(message)` on appear (prefix "Error:" for error/warning types); skip or lengthen auto-dismiss while VoiceOver or Switch Control is running; cancel the sleep on manual dismiss.
2. `SaveStatusView`: announce on `.saved` and on failure.
3. `FormErrorSummary`: `.onChange(of: errors, initial: true)`.
4. Auth: `.onChange(of: viewModel.errorMessage)` → announce, and move `@AccessibilityFocusState` to the banner; on signup scroll to it. Remove the reset-success auto-redirect or make it ≥ 20 s and cancellable.
5. Coach detail / interaction detail: present post-load errors with `.alert` bound to `errorMessage`.
6. Replace per-screen hand-rolled toasts with the shared one once it announces.

## Done when

Unit tests using `MockAccessibilityAnnouncer` cover the toast, save-status and auth error paths, and no success or error message disappears in under ~5 s without being announced.

## Evidence

Confirmed by reading the source (the three shared components and the coach-detail error path were re-read during consolidation). Not verified with VoiceOver on a device. Severity: **High**.

Part of the iOS accessibility audit — tracking issue: TRACKING
