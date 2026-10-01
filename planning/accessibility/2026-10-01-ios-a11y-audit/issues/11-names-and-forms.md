## Problem

Basic labelling is mostly present (796 `accessibilityLabel` uses), but a set of controls and form fields have no name, the wrong name, or do not expose their state.

### A. Fields and controls with no accessible name, or named by their placeholder

- GPA, SAT and ACT fields are all `TextField("–", …)` — VoiceOver reads three fields called "dash": `Features/Preferences/Views/Tabs/AcademicsSocialTab.swift:98,120`.
- Twitter / Instagram / TikTok all read "@username"; phone reads "(555) 123-4567": `BasicsTab.swift:154,171-177`. History "Team"/"Coach" ×4 grades: `HistoryTab.swift:135,137,156,241,243`. Also `AthleticsTab.swift:243,275`, `PublicTab.swift:153`, `CoreCoursesEditor.swift:58`.
- Bio and "What I'm Looking For" `TextEditor`s have no label: `Features/PublicProfile/Views/PublicTab.swift:213-221,233-241`.
- Quick Communication message editor: `Features/Coaches/Views/QuickCommunicationView.swift:715-723`.
- Create Event has four `DatePicker("")` with `.labelsHidden()`: `Features/Events/Views/CreateEventView.swift:196-205,214-226,235-244,253-262`.
- Coach-log filter menus read only their current value: `CoachInteractionsLogSection.swift:123-141`.
- Public-profile section reorder: both chevrons share one label with no direction ("Reorder Athletic Metrics"): `PublicTab.swift:343-362`.
- Header colour swatches are `onTapGesture` shapes with no button trait: `Features/PublicProfile/Components/HeaderColorPicker.swift:10-19`.
- Video link rows and user deadline rows are editable only through an unlabelled tap gesture: `VideoLinksEditorView.swift:87-93,128-136`, `DeadlinesListView.swift:208-224`.
- Onboarding recommendation cards all have identical "Add" / "Not a fit" buttons with no school name: `OnboardingStepTwoView.swift:225-239`.
- Coach cards repeat "Email coach" / "Text coach" / "Call coach" with no name; header links read only the address or handle: `CoachCardView.swift:195,210`, `CoachDetailHeader.swift:102,119`.

### B. State not exposed

- Expanded / collapsed: `CoachInteractionsLogSection.swift:203-249`, `CollapsibleSection.swift:15-25`, `CommonWorriesWidget.swift:53-66`, `DeadlinesListView.swift:143-153`, Help FAQ `HelpSectionDetailView.swift:375-394`.
- Selected: share-sheet schools state the selection only in the hint — `DocumentShareSheet.swift:44-61`; events calendar selected/today — `EventsCalendarView.swift:107-128`.
- Reordering gives no feedback about the new position: `AthleticsTab.swift:349-379`, `PublicTab.swift:341-379`.
- Primary buttons that look disabled but are not — `.disabled` is on the label, not the `Button`: `SignupView.swift:670-671`, `ResetPasswordView.swift:158-159`, `ForgotPasswordView.swift:126-127`, `EmailVerificationView.swift:171-172`.

### C. Headings

Section titles without `.isHeader`, so the Headings rotor skips them. One-line fixes that cover many screens: `Features/Coaches/Components/SectionCard.swift:12-16` (six coach-detail sections), the four `cardSection` helpers in the Player Profile tabs (`BasicsTab.swift:400-405`, `AthleticsTab.swift:470-475`, `AcademicsSocialTab.swift:142-147`, `HistoryTab.swift:249-254`), `PublicTab.swift:486`, `Features/Help/Components/HelpSectionHeader.swift:15-27` (about 30 uses). Remaining per-file lists are in the area reports. Banners wrongly carry `.isHeader` (`LoginView.swift:111-126`, `InfoBanner.swift:33-36`), as do three offer stat tiles (`OfferSummaryCard.swift:25`).

### D. Forms

- Placeholder-only fields (VoiceOver labels exist, but the visible name disappears once filled — a low-vision and cognitive problem): `SchoolBasicInfoSheet.swift:15-60`, `CoachEditForm.swift:23-115`, `ProfileView.swift:164,228,235,291,295,299`, `HomeLocationView.swift:33-61`, `CreateEventView.swift:113-330`, `EditEventSheet.swift:41-136`, and others in the area reports.
- Edit Event takes dates and times as free text with the format only in the placeholder: `Features/Events/Components/EventDetail/EditEventSheet.swift:61-70` (Create Event uses real `DatePicker`s).
- Video link Save is silently disabled when the URL has no scheme: `AddEditVideoLinkView.swift:20-23,35-44,69`.
- Number-pad fields with no way to dismiss the keyboard: `ScholarshipCalculatorView.swift:241-245`, `CreateEventView.swift:133-135`, `EditEventSheet.swift:113-115`, `EventMetricForm.swift:29-31` (the existing `.keyboardFieldNavigation` modifier solves this).
- Shared notes save only on focus loss, with no Done button: `Features/Coaches/Components/NotesSection.swift:25-40`.
- A 1…5000 stepper in steps of 1: `AddPreferenceSheet.swift:32`.
- Offer comparison sheet has no close control: `OfferComparisonSheet.swift:8-19`.
- Inline forms open off-screen with no focus move: `EventDetailView.swift:157-159`, `OffersListView.swift:75-77,121-136`, `OfferDetailView.swift:129-136,151-153`.

### E. Wrong words

- Password-reset screens tell VoiceOver "Email verified successfully" and show "Email verified! You can now access the app": `VerificationStatusIcon.swift:10-21,34-35`, `InfoBanner.swift:67-94`, used at `ForgotPasswordView.swift:140,165`, `ResetPasswordView.swift:194,207,235`.
- "Face ID" is hard-coded on Touch ID devices: `BiometricLockView.swift:24-44`.

## Fix

Per item as described; for A, add `.accessibilityLabel(<field name>)` to each control and hide the duplicate visual label. For B, `.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")` and `.isSelected`. For D, `LabeledContent` or `FormFieldWrapper` (after the fix in the combined-elements issue).

## Done when

Every interactive control on the listed screens has a unique, meaningful spoken name and exposes its state.

## Evidence

Source review; the items in A were read in full by the reviewers and a sample re-checked during consolidation. Not verified with VoiceOver on a device. Severity: **High** for section A; Medium for B–E.

Part of the iOS accessibility audit — tracking issue: TRACKING
