## Problem

Many controls have an `accessibilityLabel` that does not contain the text shown on screen, so a Voice Control user who says what they see ("Tap Save", "Tap Role") gets no match and has to fall back to numbers. The app has zero uses of `accessibilityInputLabels`. WCAG 2.5.3 (Label in Name).

Several labels also include the control type ("School picker", "Subject field"), which makes VoiceOver say it twice, or put gesture instructions in the label or hint.

### Visible text → spoken label

**Auth**
- "Create one now" → "Create account" (`LoginView.swift:244,254`)
- "Send Reset Link" → "Send password reset link"; "Use Different Email" → "Use a different email address" (`ForgotPasswordView.swift:111,129,194,200`)
- "Request New Link" → "Request a new password reset link" (`ResetPasswordView.swift:254,264`)
- "Use Face ID" → "Sign in with Face ID"; "Use Password Instead" → "Sign in with password" (`BiometricLockView.swift:36,44,47,52`)
- Support address → "Email support at therecruitingcompass dot com" (`LegalEmailLink.swift:19,25`)

**Schools / Coaches / Interactions**
- "D1" / "Contacted" / "CA" → "Division filter" etc.; "Sort: Name" → "Sort order" (`SchoolFilterBar.swift:57-64,81-88,105-112,161-167`)
- "Done" → "Dismiss keyboard" (`SchoolNotesSection.swift:34-37`); "Add Coach" → "Add a coach to this school" (`SchoolCoachesPanel.swift:114-119`)
- "Role" → "Filter by role"; "Type" → "Filter by type" (`CoachFilterBar.swift:39,65,99`, `InteractionFilterBar.swift:39,69,99,129,175`)
- "Save" → "Save coach changes"; "Set next contact date" → "Toggle next contact date" (`CoachEditForm.swift:153,182`)
- "Copy Link" → "Copy profile link" (`CoachDetailView.swift:372`); "DM on Instagram" → "Open Instagram profile @…" (`QuickCommunicationView.swift:466`)
- Log Interaction: "School picker", "Coach picker", "Subject field", and Cancel labelled "Cancel and return to school details" although the form opens from four places (`AddInteractionView.swift:64,148,157,185,213,240,263,278,291,315`)
- "Email (3)" → "Filter by Email, 3 templates" (`CommunicationTemplatesView.swift:138`)

**Dashboard / Performance**
- "Done" → "Complete suggestion" (`ActionItemCard.swift:96-103`); "Skip" → "Dismiss <name>" (`SchoolRecommendationsWidget.swift:117-126`)
- "I'm good for now" → "Dismiss getting started checklist" (`GettingStartedChecklistWidget.swift:57-65`)
- "Show N more" → "View all action items" (`ActionItemsWidget.swift:41-52`); similar in `PerformanceMetricsWidget.swift:38-52`, `UpcomingEventsWidget.swift:67-81`
- "Copy link" / "Copied!" → "Copy public profile link" (`DashboardPublicProfileCard.swift:102,109`)
- "Date" → "Recording date"; "Metric type selector" (`MetricFormView.swift:71,97-99`)

**Profile / Family / Settings**
- "Choose Photo" → "Choose profile photo" (`BasicsTab.swift:87-89`); "Upload Photo" → "Upload profile photo"; "Yes, delete my account" → "Confirm account deletion" (`ProfileView.swift:107,111,458,465`)
- "Use My Location" → "Use current location"; "Lookup from Address" → "Lookup coordinates from address" (`HomeLocationView.swift:22,30,82,90`)
- "High-Priority Only" → "Email high-priority notifications only" (`NotificationPreferencesView.swift:70,74`)
- "Download as PDF" → "Download profile as PDF" (`PublicTab.swift:438,446`)
- "Player's first name" → "Athlete first name" (the screen says Player, the label says Athlete) (`ParentOnboardingWizardView.swift:67,71,96,105`)

**Events / Offers / Documents**
- "Calculate" → "Scholarship Calculator" (`ScholarshipCalculatorView.swift:89-94`); "Add Metric" → "Add a new performance metric" (`MetricsSectionView.swift:51-53`)
- "Clear Filters" → "Clear all active filters" (`EventsListView.swift:224-227`); current sort name → "Sort documents" (`DocumentFilterBar.swift:22,32`)
- "First name field", "Coach role picker" (`Shared/Components/Forms/AddCoachSheet.swift:19,23,30,37`)

### Gesture words and wrong hints

- "Tap to open" baked into labels, including on rows with no link: `SchoolBasicInfoDisplaySection.swift:49,87,127,169,200`.
- "Double tap to…" hints across filter bars, chips and cards (lists in the area reports).
- Wrong hint: label "Back to welcome screen" with hint "Returns to the login screen" (`LoginView.swift:88-89`); "Opens document details" when it opens the viewer (`DocumentCardView.swift:38`, `DocumentListViewRow.swift:31`).

## Fix

Start each label with the visible text and move the extra context to `accessibilityHint` / `accessibilityValue`, or keep the descriptive label and add `.accessibilityInputLabels(["Save", …])`. Drop control-type words and gesture instructions.

## Done when

Voice Control "Tap <visible text>" works for every control listed.

## Evidence

Source review; mismatches are literal string comparisons, so confidence is high. Not tested with Voice Control. Severity: **Medium** (everything remains operable through number overlays).

Part of the iOS accessibility audit — tracking issue: TRACKING
