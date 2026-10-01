# Accessibility findings — Shared/, Core/ UI, Events, Documents, Offers

Audited tree: `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass`
(the main checkout named in the brief). Static read only; nothing was built or run.

Scope read in full: every file in `Shared/Components`, `Shared/Navigation`, `Core/Theme`, the two UI-ish files in
`Core` (`AccessibilityAnnouncing`, `TurnstileWidgetView`), and every View/Component file in `Features/Events`,
`Features/Documents`, `Features/Offers`. View models were read only where they drive what is shown or announced.

Counts: **1 Blocker, 4 High, 21 Medium, 12 Low.**

Usage counts in "where" lines are call sites outside the component's own file (grep, previews excluded where obvious).

---

## Blocker

### [Blocker] Document viewer removes all its controls after 3 s on videos; the only way back is an unlabelled tap gesture
- category: timing
- confidence: medium
- where: `Features/Documents/Views/DocumentViewerView.swift:72-80, 107-127`; `Features/Documents/ViewModels/DocumentViewerViewModel.swift:134-141`
- what: For video documents `scheduleToolbarAutoHide()` sets `isToolbarVisible = false` after `Task.sleep(for: .seconds(3))`. The top toolbar (Close, Share, Download) and bottom bar (previous/next) are then removed from the hierarchy (`if viewModel.isToolbarVisible { topToolbar }`). They come back only via `.onTapGesture { … isToolbarVisible.toggle() }` on the root `ZStack`, which has no accessibility element, trait or action. The view is a `fullScreenCover`, there is no `.accessibilityAction(.escape)`, and the other exit is a 150 pt drag-down gesture. The timer is not gated on VoiceOver / Switch Control running.
- user impact: A VoiceOver or Switch Control user who opens a highlight video has 3 seconds to find Close before every control disappears, and may be unable to leave the viewer. Whether VoiceOver's synthesized tap on the embedded `AVPlayerViewController` reaches the SwiftUI tap gesture is the unverified part (see simulator list).
- fix: Do not auto-hide when `UIAccessibility.isVoiceOverRunning || isSwitchControlRunning` (or `@Environment(\.accessibilityVoiceOverEnabled)`); add `.accessibilityAction(.escape) { dismiss() }` to the cover root; keep the Close button permanently in the tree (fade only Share/Download/paging); give the toggle an accessibility representation (`.accessibilityAction(named: "Show controls")`).

---

## High

### [High] `FormFieldWrapper` collapses the field, its label and its error into one element and overrides the label
- category: voiceover
- confidence: medium
- where: `Shared/Components/Forms/FormFieldWrapper.swift:55-56` — 20 call sites: `Features/Coaches/Components/CoachFormView.swift` (10), `Features/Schools/Presentation/Views/Components/SchoolFormView.swift` (10)
- what: The wrapper ends with `.accessibilityElement(children: .combine)` + `.accessibilityLabel(buildAccessibilityLabel())` around `content()`. `content` is an interactive control — a `TextField`, a menu `Picker`, and in one case `CoachTagsCard` with its own add/remove buttons (`CoachFormView.swift:63-70`). Combining merges all of that into a single element and the explicit label replaces whatever the children contributed, including each field's own `.accessibilityLabel`/`.accessibilityHint` (e.g. `CoachFormView.swift:119-120`).
- user impact: On the add/edit coach and add/edit school forms, VoiceOver gets one element per field group named e.g. "First Name, required"; the typed value, the picker's current selection and the individual tag buttons are not separately reachable, and editing depends on how SwiftUI forwards activation from a combined element. If activation is not forwarded this is a Blocker for those forms.
- fix: Remove `.combine` and the label override from the wrapper. Hide the visual label `Text` from accessibility (`.accessibilityHidden(true)`) and let the control carry the name; attach the error to the control with `.accessibilityValue`/`.accessibilityHint` or post it as an announcement. Keep the asterisk hidden as it is today.

### [High] Shared `Toast` is never announced and auto-dismisses after 3 seconds
- category: voiceover
- confidence: high
- where: `Shared/Components/Toast.swift:39-41`; `Shared/Components/ToastModifier.swift:19-24, 43` — `.toast(` is used in 10 screens (12 call sites): `Features/Offers/Views/OffersListView.swift:93`, `InteractionsListView`, `CoachesListView`, `QuickCommunicationView`, `InviteJoinView`, `FamilyManagementView`, `InviteAthleteView`, `InboundDraftsView`, `SchoolDetailView`, `SchoolsListView`
- what: The toast is an `.overlay(alignment: .top)` that appears, sleeps `duration` (default 3.0 s) and removes itself. Nothing posts `AccessibilityNotification.Announcement`; the only accessibility modifier is `.accessibilityAddTraits(.updatesFrequently)`, which does not announce. There is no pause/extend, and the toast type (success vs error) is carried only by the hidden icon.
- user impact: Confirmations such as "Offer logged successfully" / "Offer deleted" (`OffersListViewModel.swift:206, 235`) and error toasts are never heard by VoiceOver users and vanish before a slow reader or Switch Control user can reach them.
- fix: In `ToastModifier`, post `AccessibilityNotification.Announcement(message)` when the toast appears (prefix "Error:" for `.error`/`.warning`). Skip or lengthen the auto-dismiss while VoiceOver is running, and cancel the sleep task on manual dismiss.

### [High] Create Event: four date/time pickers have no accessible name
- category: forms
- confidence: high
- where: `Features/Events/Views/CreateEventView.swift:196-205` (start time), `214-226` (end date), `235-244` (end time), `253-262` (check-in time)
- what: Each optional picker is `DatePicker("", selection: …)` with `.labelsHidden()` and no `.accessibilityLabel`. Only an `.accessibilityIdentifier` is set.
- user impact: VoiceOver reads four consecutive date/time controls by value only ("3:00 PM"); Voice Control has no name to target. The user must infer which is which from the preceding toggle.
- fix: Give each a real title and keep it hidden visually: `DatePicker("End Date", …).labelsHidden()` (the title becomes the accessibility label), or add `.accessibilityLabel("Start time")` etc.

### [High] Document upload: the selected file name is hidden from VoiceOver
- category: voiceover
- confidence: high
- where: `Features/Documents/Components/DocumentUploadSheet.swift:57-68`
- what: The button's visible text is `viewModel.selectedFileName ?? "Select file"`, but `.accessibilityLabel(String(localized: "Select file"))` is fixed, so the label never changes after a file is picked. Upload progress (`:76-90`) and `uploadError` (`:92-96`) are also not announced.
- user impact: A VoiceOver user cannot confirm which file they chose before tapping Upload, and gets no feedback when the upload progresses or fails.
- fix: Drop the fixed label (or use `.accessibilityLabel("Select file")` + `.accessibilityValue(viewModel.selectedFileName ?? "None selected")`); announce `uploadError` and completion via `AccessibilityNotification.Announcement`.

---

## Medium

### [Medium] `FormErrorSummary` does not announce on first appearance and swallows its dismiss button
- category: forms
- confidence: high
- where: `Shared/Components/Forms/FormErrorSummary.swift:16, 59-67` — 3 call sites: `Features/Coaches/Views/AddCoachView.swift:108`, `Features/Interactions/Views/InteractionAddSchoolSheet.swift:223`, `Features/Schools/Presentation/Views/AddSchoolView.swift:237`
- what: The announcement lives in `.onChange(of: errors)` inside `if !errors.isEmpty { … }`. When errors go from empty to non-empty the view is inserted fresh and `onChange` does not fire for the initial value, so the first failed submit is silent; only later changes are announced. Separately, `.accessibilityElement(children: .combine)` + `.accessibilityLabel("Form errors")` merges the "Dismiss error summary" button (`:31-38`) into the summary, so its name is lost. (`AddCoachViewModel` and `AddSchoolViewModel` post their own announcements; `InteractionAddSchoolSheet` has none.)
- user impact: On the interaction "add school" sheet the first validation failure is not spoken; on all three, the dismiss control is not discoverable as such.
- fix: Use `.onChange(of: errors, initial: true)` or `.onAppear` for the first announcement; use `children: .contain` (or keep the list combined but leave the dismiss button outside the combined group).

### [Medium] Event detail success toast: not announced, 2-second lifetime
- category: voiceover
- confidence: high
- where: `Features/Events/Views/EventDetailView.swift:90-94, 234-249`; `Features/Events/ViewModels/EventDetailViewModel.swift:490-491`
- what: A hand-rolled toast (`Text(message)… .task { try? await Task.sleep(for: .seconds(2)); withAnimation { viewModel.showSuccessToast = false } }`) with no announcement. No file in `Features/Events` posts an accessibility notification.
- user impact: "Marked as attended", coach added/removed, metric saved and interaction logged confirmations are silent for VoiceOver.
- fix: Replace with the shared `.toast` once it announces, or post `AccessibilityNotification.Announcement(message)` in `showSuccess`.

### [Medium] `SaveStatusView` autosave state changes are silent
- category: voiceover
- confidence: high
- where: `Shared/Components/SaveStatusView.swift:16-31` — 7 screens: `SchoolDetailView:52`, `CoachDetailView:77`, `PlayerDetailsView:37`, `HomeLocationView:145`, `NotificationPreferencesView:144`, `SchoolPreferencesView:109`, `DashboardCustomizationView:170`
- what: "Saving…" / "Saved" appear and disappear with no announcement; the `ProgressView` is unlabelled and `Image(systemName: "checkmark.circle.fill")` is not hidden.
- user impact: VoiceOver users editing autosaved screens never learn whether a change was saved.
- fix: Announce on transition to `.saved` (and on failure); `.accessibilityElement(children: .combine)` on each state row, hide the checkmark.

### [Medium] Create Event validation errors are drawn as overlays and never announced
- category: forms
- confidence: high
- where: `Features/Events/Views/CreateEventView.swift:109-111, 116-118, 143-145, 186-188, 224-226, 392-400`; `Features/Events/ViewModels/CreateEventViewModel.swift:163-192`
- what: `validationMessage(for:)` is attached with `.overlay(alignment: .bottom)`, so the error text is painted on top of the field/picker row instead of taking layout space. Nothing announces errors or moves focus when `validateForm()` fails (end-date-before-start and invalid URL are the reachable cases, since Create is disabled until type/name/start date are set).
- user impact: After tapping Create, a VoiceOver user hears nothing and the form does not submit; sighted users at larger text sizes get the caption overlapping the field's own text.
- fix: Render the message as a row below the field inside the `Section`; on failed validation post an announcement and move `@AccessibilityFocusState` to the first invalid field.

### [Medium] Placeholder-only text fields (no persistent visible label)
- category: forms
- confidence: high
- where: `Features/Events/Views/CreateEventView.swift:113, 133, 138, 274, 277, 280, 311, 330`; `Features/Events/Components/EventDetail/EditEventSheet.swift:41, 61-69, 79-85, 95, 99, 113, 136`; `Features/Events/Components/EventDetail/EventMetricForm.swift:29, 35, 42`; `Features/Events/Components/AddSchoolSheet.swift:18, 20`; `Features/Events/Components/OtherSchoolSheet.swift:12`; `Shared/Components/Forms/AddCoachSheet.swift:17, 21, 25`; `Features/Documents/Components/DocumentUploadSheet.swift:28, 49`; `Features/Documents/Components/DocumentEditSheet.swift:10, 38`
- what: Fields are `TextField("Event Name *", text:)` etc. inside a `Form` with only a section header. Once text is entered the placeholder — the only visible name, and the only required marker (`*`) — disappears. Accessibility labels are present, so this is a visual/cognitive and low-vision issue, not a VoiceOver one.
- user impact: In Edit Event, a filled form shows five adjacent unlabeled date/time strings and four unlabeled location strings; users with memory or low-vision needs cannot tell fields apart.
- fix: Use `LabeledContent("Event Name") { TextField(…) }` or `FormFieldWrapper` (after the High fix above) so the label persists.

### [Medium] Edit Event takes dates and times as free text with the format only in the placeholder
- category: forms
- confidence: high
- where: `Features/Events/Components/EventDetail/EditEventSheet.swift:61-70`
- what: `TextField("Start Date (YYYY-MM-DD)", …).accessibilityLabel("Start date")`; time fields have no format guidance at all. The accessibility label drops the required format, and the visible format disappears once the field has a value. Create Event uses real `DatePicker`s for the same data.
- user impact: VoiceOver users are never told the expected format; all users lose it as soon as the field is populated (which it always is when editing).
- fix: Use `DatePicker` as in `CreateEventView`; if text entry stays, put the format in `.accessibilityHint` and a persistent caption.

### [Medium] Share sheet: selected state exists only in the hint
- category: voiceover
- confidence: high
- where: `Features/Documents/Components/DocumentShareSheet.swift:44-61`
- what: `.accessibilityHint(selected ? "Selected. Double tap to deselect." : "Double tap to add")`; no `.isSelected` trait or `accessibilityValue`. Hints are optional (users can turn them off) and are read after a delay.
- user impact: With hints off, a VoiceOver user cannot tell which schools are ticked before pressing Save.
- fix: `.accessibilityAddTraits(isSelected ? .isSelected : [])` as `DocumentFilterSheet.swift:24` already does; shorten the hint.

### [Medium] Documents sort menu hides the current sort order
- category: voiceover
- confidence: high
- where: `Features/Documents/Components/DocumentFilterBar.swift:14-33`
- what: The menu label shows `sortBy.label`, but `.accessibilityLabel("Sort documents")` replaces it and no value is set. The options are plain `Button`s, so the open menu has no checkmark either.
- user impact: VoiceOver users cannot find out the active sort; Voice Control users cannot say the visible text.
- fix: Use `Picker` inside the `Menu` (gives a checkmark and selected trait) and add `.accessibilityValue(sortBy.label)`.

### [Medium] Events calendar: selected/today state not exposed; day number in a fixed 32 pt box
- category: voiceover
- confidence: high (state) / medium (Dynamic Type)
- where: `Features/Events/Components/EventsCalendarView.swift:107-128, 147-153`
- what: The cell label is "<full date>. Has events." — `isSelected` and `isToday` only change the fill (`:137-144`) with no trait or text. The number is `Text(dayNumber).font(.subheadline).frame(width: 32, height: 32)` in a 7-column grid, so it cannot grow with accessibility text sizes. Cells without events are `.disabled`, so the whole month reads as mostly "dimmed".
- user impact: VoiceOver users cannot tell which day is selected or which is today; at accessibility sizes two-digit days will truncate.
- fix: Add `.accessibilityAddTraits(isSelected ? .isSelected : [])` and append "Today" to the label; cap the grid with `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` or size the circle with `@ScaledMetric`.

### [Medium] Custom accessibility labels drop information that is visible on screen
- category: voiceover
- confidence: high
- where: `Features/Events/Views/EventsListView.swift:261, 314-320` (row label omits time, city/state, cost, notes; reads the raw `event.startDate` string instead of the formatted range); `Features/Events/Components/EventDetail/MetricCardView.swift:51-54` (omits date and notes); `Features/Documents/Components/DocumentCardView.swift:94-96` and `DocumentListViewRow.swift:92-94` (omit school name and version); `Features/Offers/Components/ScholarshipCalculatorView.swift:189-191` (omits the additional-aid column); `Features/Offers/Components/OfferCard.swift:110` (checkbox is "Select for comparison" with no school name; card label omits offer date and notes)
- what: Each element sets an explicit `.accessibilityLabel` that is a subset of what the row draws.
- user impact: VoiceOver users get less than sighted users on the main Events, Documents and Offers lists; every offer checkbox sounds identical.
- fix: Build the label from the same fields the row renders, or drop the override and let the combined children speak; include the school name in the checkbox label.

### [Medium] Inline forms open off-screen with no focus move or announcement
- category: voiceover
- confidence: medium
- where: `Features/Events/Views/EventDetailView.swift:157-159` → `MetricsSectionView.swift:36-45` ("Add Metric" in the toolbar menu reveals a form several sections down the list); `Features/Offers/Views/OffersListView.swift:75-77, 121-136` ("+" inserts `AddOfferForm` at the top of the scroll view regardless of scroll position); `Features/Offers/Views/OfferDetailView.swift:129-136, 151-153` and `OfferDetailViewModel.swift:193-199` (Edit and the calculator's "Save to Offer" reveal `OfferEditForm` below the calculator)
- what: State flips (`showMetricForm`, `showAddForm`, `isEditing`) insert a form elsewhere in the scroll content; nothing scrolls to it, posts a layout-changed notification or sets `@AccessibilityFocusState`.
- user impact: A VoiceOver user activates the control and perceives no result; "Save to Offer" appears to do nothing (it only pre-fills an edit form that still needs Save Changes).
- fix: Present these forms as sheets, or scroll to the form and set accessibility focus on its heading; announce "Edit form opened".

### [Medium] Hit targets below 44 pt
- category: hit-target
- confidence: high
- where: `Shared/Components/FilterChip.swift:37` (remove "x" is `minWidth: 24, minHeight: 24`; outlined chip `minHeight` 0, filled 32 — 15 call sites in 5 files); `Shared/Components/FilterChipContainer.swift:42-49` ("Clear all" is bare text — 4 call sites); `Features/Documents/Components/DocumentFilterBar.swift:20-31, 39-51, 84-87` (sort menu ~36 pt, "Filter" text button, caption "Clear filters"); `Features/Documents/Components/DocumentErrorBanner.swift:13-15` and `Features/Documents/Views/DocumentsListView.swift:222-226` (caption "Retry"); `Features/Documents/Components/DocumentVersionRow.swift:31-35` (caption "View" link); `Features/Offers/Components/OfferEditForm.swift:144-153` (caption "Clear", "Set Deadline"); `Features/Events/Components/EventDetail/MetricsSectionView.swift:60-65` (export icon in a section header, `.plain`, no frame)
- what: Tappable text/icons at caption or subheadline size with no `frame(minWidth:minHeight:)` or `contentShape`.
- user impact: Hard to hit for users with motor impairments; the filter-chip remove button is the worst because it is the only tappable part of the chip.
- fix: `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` inside each button label; make the whole `FilterChip` the button.

### [Medium] Likely contrast failures: system colours and brand-600 shades used as small text
- category: color
- confidence: medium (ratios are hand-calculated; see Design tokens)
- where:
  - Red error text `.foregroundStyle(.red)` at caption size: `Shared/Components/Forms/FieldError.swift:19, 24` (every `FormFieldWrapper` error), `Features/Events/Views/CreateEventView.swift:397`, `Features/Documents/Components/DocumentUploadSheet.swift:95`, `Features/Offers/Components/OfferEditForm.swift:148`, `Shared/Components/Forms/CharacterCountView.swift:20` (also `.orange`)
  - White text on `Color.red`: `Shared/Components/Forms/FormErrorSummary.swift:57` (plus `.white.opacity(0.7)` dismiss icon `:35`), `Features/Documents/Views/DocumentsListView.swift:229`
  - White text on `Color.blue`: `Shared/Components/FilterChip.swift:70, 79` (filled), `Shared/Components/FilterMenuButton.swift:49, 58` (rounded/active)
  - Coloured text on its own 10–20 % tint: `Features/Events/Components/EventRowView.swift:60-61, 76-77`, `Features/Events/Components/EventDetail/BadgeLabel.swift:15-16` (`.green/.cyan/.orange/.gray/.purple/.blue`), `Features/Documents/Components/DocumentCardView.swift:89-90`, `DocumentListViewRow.swift:22-23` (`.green`), `Features/Offers/Components/OfferCard.swift:159-162`, `OfferHeaderView.swift:16-17` (`statusColor`), `Features/Offers/Components/ScholarshipCalculatorView.swift:254-268` (caption2 in `.orange/.green/.blue/.red`), `:173-184`
  - Coloured large numerals: `Features/Documents/Components/StatisticsCardsRow.swift:50-53` (`.green`, `.orange`)
  - White on green: `Features/Events/Views/EventDetailView.swift:236-239` (`.green.gradient` toast), `Features/Offers/Components/ScholarshipCalculatorView.swift:210-211` (`.borderedProminent.tint(.green)`), `Features/Documents/Components/DocumentHeaderCard.swift:49-50` (`.tint(.primaryGreen)`), `Features/Documents/Components/DocumentShareSheet.swift:82` (`primaryGreen` bar-button text)
  - Tertiary text: `Features/Offers/Components/ScholarshipCalculatorView.swift:247-249` (`.tertiary` caption2 helper text)
- what: Light-mode system red (~3.6:1 on white), green (~2.2:1), orange (~2.2:1), cyan and blue (~4.0:1 with white) are below 4.5:1 for small text; emerald-600 is ~3.8:1 against white either way round.
- user impact: Error messages, status badges and several primary buttons are hard to read for low-vision users; blocks an honest "Sufficient Contrast" label.
- fix: Route these through adaptive tokens: `Color.errorRed`-style text tokens with dark variants, `BadgeColor` (100 background / 700 foreground) for all pills, emerald-700/blue-700 for filled buttons.

### [Medium] Document viewer: "Retry" is probably white-on-white, and the top toolbar scrim covers the whole document
- category: color
- confidence: medium
- where: `Features/Documents/Views/DocumentViewerView.swift:301-305` and `:174-232`
- what: `Button("Retry").buttonStyle(.borderedProminent).tint(.white)` — the prominent style draws a tint-coloured fill with a white label. Separately, `topToolbar` is `VStack { HStack…; Spacer() }.background(Color.black.opacity(0.8))`; the `Spacer` makes the stack full-height, so the 80 % black background covers the entire document whenever the toolbar is visible (always, for PDFs and images, until the user taps).
- user impact: The primary recovery action on the error overlay may be invisible; documents are shown through an 80 % black scrim until the chrome is dismissed.
- fix: `.tint(.white).foregroundStyle(.black)` or a bordered style; move the background onto the toolbar `HStack` only (as `bottomNavigationBar` already does at `:266`).

### [Medium] Dark mode: non-adaptive colours that lose contrast
- category: dark-mode
- confidence: medium
- where: `Shared/Components/OfflineBanner.swift:9, 13, 17` (white text on `Color.secondaryText`, which becomes `#94a3b8` in dark — mounted app-wide at `TheRecruitingCompassApp.swift:270`); `Shared/Components/InterestResultCard.swift:22, 34` (`BadgeColor.foregroundColor` 700 shade on a 10 %-opacity background, i.e. dark text on a dark card); `Features/Offers/Models/OfferStatus.swift:26-34` and `Features/Offers/Models/DeadlineUrgency.swift:12` used as text in `OfferCard.swift:135-146, 159`, `OfferHeaderView.swift:17`, `OfferFinancialSummary.swift:36, 42`, `OfferSummaryCard.swift:13` (`accentBlue`, `errorRed`, `successGreen` are fixed 600 shades with no dark variant); `Features/Events/Components/EventDetail/EventCoachCard.swift:48-50` (white initials on `amberGold`, which is `#fbbf24` in dark)
- what: `Color.accentBlue` / `.errorRed` / `.successGreen` are plain `Color.Brand.*600` constants, unlike `secondaryText`/`darkSlate`/`amberGold` which use `Color(light:dark:)`. Used as text on dark cards they are roughly 3.2–4.4:1.
- user impact: Offline banner, offer status/deadline text and interest result headings are low-contrast in dark mode.
- fix: Give `accentBlue`, `errorRed`, `successGreen` dark variants (400/500 shades) or add dedicated text tokens; set the offline banner to a fixed dark slate with white text; use adaptive text on `InterestResultCard`.

### [Medium] Layouts that cannot reflow at accessibility text sizes
- category: dynamic-type
- confidence: medium
- where: `Features/Offers/Components/OfferFinancialSummary.swift:11-59` (three equal columns of `.title2.bold` money/deadline values; date is `.lineLimit(1)` at `:48`); `Features/Documents/Components/DocumentHeaderCard.swift:34-62` (three `minWidth: 88` prominent buttons in one `HStack`); `Features/Offers/Components/ScholarshipCalculatorView.swift:161-186` (five text columns, fixed `width: 50` and `width: 70`) and `:132-137` (5-segment picker); `Features/Offers/Components/OfferFilterBar.swift:8-48` (two menu pickers per row); `Features/Offers/Components/OfferSummaryCards.swift:9-13`; `Shared/Components/InfoRow.swift:9-19` (label/value side by side — 6 call sites); `Features/Documents/Components/DocumentCardView.swift:76-81`, `DocumentListViewRow.swift:80-83`, `Features/Documents/Views/DocumentViewerView.swift:185-189`, `Features/Offers/Components/OfferCard.swift:35-38`, `Features/Events/Components/EventRowView.swift:29-32` (`lineLimit(1)` on title/metadata)
- what: Fixed multi-column `HStack`s with no `ViewThatFits`/`dynamicTypeSize` branch. There are zero `dynamicTypeSize` uses in this area; `AdaptiveHStackVStack` exists for this but has no call sites.
- user impact: At AX sizes, amounts and deadlines wrap mid-number or truncate; the Edit/Share/Delete row overflows.
- fix: Wrap in `ViewThatFits { HStack… ; VStack… }` or switch on `dynamicTypeSize.isAccessibilitySize`; remove `lineLimit(1)` on titles.

### [Medium] Scholarship year breakdown distinguishes columns by colour only
- category: color
- confidence: high
- where: `Features/Offers/Components/ScholarshipCalculatorView.swift:160-186`
- what: Each row is "Year N  $cost  -$scholarship  -$aid  $net" with no column headers; scholarship vs additional aid differ only by `.green` vs `.blue`, and net cost by `.red`.
- user impact: Colour-blind users, and anyone using Differentiate Without Colour, cannot tell which deduction is which.
- fix: Add a header row (Cost / Scholarship / Aid / You pay) or inline text labels.

### [Medium] Offer comparison sheet has no close control
- category: timing
- confidence: high
- where: `Features/Offers/Components/OfferComparisonSheet.swift:8-19`
- what: The sheet's `NavigationStack` has a title but no toolbar item; the only dismissal is the swipe-down gesture (or VoiceOver's scrub).
- user impact: Voice Control and Switch Control users have no named control to leave the comparison.
- fix: Add `ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }`.

### [Medium] Offer card nests two buttons inside a `NavigationLink`
- category: voiceover
- confidence: low
- where: `Features/Offers/Views/OffersListView.swift:164-176`; `Features/Offers/Components/OfferCard.swift:18-31, 85-100`
- what: The whole `OfferCard` is the label of a `NavigationLink`, and the card contains a selection `Button`, a combined text block with its own label/hint ("Tap to view offer details"), and a delete `Button`.
- user impact: How VoiceOver and Voice Control expose this (one link with custom actions, or three overlapping elements) is not determinable statically; either way the link and the inner block duplicate each other.
- fix: Make only the text block the `NavigationLink`, with the checkbox and delete button as siblings; or expose select/delete as `accessibilityAction(named:)` on a single row element.

### [Medium] Image preview is unlabelled and zoom is gesture-only
- category: voiceover
- confidence: high
- where: `Features/Documents/Components/Preview/ImagePreviewView.swift:44-85`
- what: The `AsyncImage` result has no `accessibilityLabel`; zoom is `MagnificationGesture` + double-tap with no `accessibilityZoomAction` or buttons.
- user impact: VoiceOver lands on an anonymous "image"; Switch Control / Voice Control users cannot zoom.
- fix: Pass the document title in and set `.accessibilityLabel(title)`; add `.accessibilityZoomAction` or +/- buttons.

### [Medium] Number-pad fields with no way to dismiss the keyboard
- category: forms
- confidence: medium
- where: `Features/Offers/Components/ScholarshipCalculatorView.swift:241-245` (four `.numberPad` fields; `keyboardFieldNavigation` is attached only to `OfferEditForm`/`AddOfferForm`); `Features/Events/Views/CreateEventView.swift:133-135`, `Features/Events/Components/EventDetail/EditEventSheet.swift:113-115`, `Features/Events/Components/EventDetail/EventMetricForm.swift:29-31` (`.decimalPad`)
- what: Numeric keypads have no return key and these views add no keyboard toolbar or `scrollDismissesKeyboard`.
- user impact: The keypad stays up over the calculator results / form buttons; hardest for VoiceOver and Switch Control users who cannot drag-dismiss.
- fix: Apply the existing `.keyboardFieldNavigation(focusedField:order:)` (`Shared/Components/Forms/KeyboardFieldNavigation.swift`) to these forms.

---

## Low

### [Low] Section titles without the header trait, and header traits on non-headings
- category: voiceover
- confidence: high
- where: missing — `Features/Documents/Components/DocumentPreviewCard.swift:8`, `DocumentVersionHistoryCard.swift:12`, `DocumentHeaderCard.swift:21`, `Features/Offers/Components/OfferEditForm.swift:13`, `ScholarshipCalculatorView.swift:156`; wrong — `Features/Offers/Components/OfferSummaryCard.swift:25` (three stat tiles marked `.isHeader`), `OfferHeaderView.swift:36-38` (school + status + type combined into one heading)
- what: `.font(.headline)` text with no `.accessibilityAddTraits(.isHeader)`; `SectionHeader` exists but has only 4 call sites app-wide.
- user impact: Heading rotor navigation is incomplete on document and offer detail and noisy on the offers list.
- fix: Use `SectionHeader`; remove `.isHeader` from the stat tiles; mark only the school name as the header.

### [Low] Labels containing the control type, gesture-instruction hints, and a wrong hint
- category: voiceover
- confidence: high
- where: `Shared/Components/Forms/AddCoachSheet.swift:19, 23, 30, 37` ("First name field", "Coach role picker"), `Shared/Components/Forms/OtherCoachSheet.swift:15`; hints — `Shared/Components/FilterChip.swift:41`, `Features/Documents/Components/DocumentListViewRow.swift:51`, `Features/Offers/Components/OfferCard.swift:87, 100, 112`, `OfferFilterBar.swift:54-63`, `AddOfferForm.swift:120`; wrong — `Features/Documents/Components/DocumentCardView.swift:38` and `DocumentListViewRow.swift:31` say "Opens document details" but `onTap` opens the full-screen viewer (`DocumentsListView.swift:171, 189`)
- user impact: "First name field, text field"; redundant "Double tap to…" speech; misleading destination.
- fix: Remove type words and gesture instructions; change the hint to "Opens the document".

### [Low] Voice Control: spoken name differs from visible text
- category: voice-control
- confidence: high
- where: `Features/Offers/Components/ScholarshipCalculatorView.swift:89-94` (shows "Calculate", label "Scholarship Calculator"); `Features/Events/Components/EventDetail/MetricsSectionView.swift:51-53` ("Add Metric" vs "Add a new performance metric"); `Features/Events/Views/EventsListView.swift:224-227` ("Clear Filters" vs "Clear all active filters"); `Shared/Components/Forms/AddCoachSheet.swift:32-37` ("Role" vs "Coach role picker"); `Features/Documents/Components/DocumentFilterBar.swift:22, 32` (current sort name vs "Sort documents"); `Shared/Components/AppErrorView.swift:119-125` (unused)
- user impact: "Tap Calculate" / "Tap Add Metric" do not work.
- fix: Start the label with the visible text or add `.accessibilityInputLabels([…])`.

### [Low] Decorative images not hidden; unlabelled spinners
- category: voiceover
- confidence: high
- where: images — `Features/Documents/Components/Preview/FallbackPreviewView.swift:11`, `PreviewUnavailableView.swift:11`, `Shared/Components/SaveStatusView.swift:26`; spinners — `Features/Documents/Views/DocumentViewerView.swift:277`, `Features/Documents/Components/Preview/VideoPreviewView.swift:44`, `ImagePreviewView.swift:89`, `Shared/Components/SaveStatusView.swift:18`, `Features/Documents/Components/DocumentVersionHistoryCard.swift:37`
- fix: `.accessibilityHidden(true)` on the icons; `.accessibilityLabel("Loading document")` etc. on the progress views.

### [Low] Animations not gated on Reduce Motion (all short fades/moves)
- category: motion
- confidence: high
- where: `Features/Offers/Components/ScholarshipCalculatorView.swift:87`; `Features/Offers/Views/OffersListView.swift:14, 76, 128`; `Features/Documents/Views/DocumentViewerView.swift:74, 79, 101, 109`; `Features/Documents/Components/Preview/ImagePreviewView.swift:74`; `Features/Events/Views/EventDetailView.swift:246`; `Shared/Components/SaveStatusView.swift:8`
- what: Plain `withAnimation {}` / `.animation(.easeInOut…)`. No carousel, shimmer-in-use or confetti in this area.
- fix: Follow the pattern already used in `AsyncButton.swift:131-140`, `ToastModifier.swift:18`, `EventsListView.swift:166-170`.

### [Low] `accessibilityLabel` applied to containers that are not accessibility elements
- category: voiceover
- confidence: low
- where: `Features/Events/Components/EventsCalendarView.swift:33`; `Features/Offers/Components/OfferEditForm.swift:132-156` (label "Deadline date" on an `HStack` holding a `DatePicker` and a "Clear" / "Set Deadline" button); `Features/Events/Views/EventsListView.swift:276-277`
- what: A label on a plain stack without `.accessibilityElement(children:)`; the effect on the children (ignored vs overriding the button names) needs a device check.
- fix: Add `.accessibilityElement(children: .contain)` where a container name is wanted, otherwise remove the label and label the inner controls.

### [Low] Emoji and placeholder strings read aloud
- category: voiceover
- confidence: high
- where: `Features/Documents/Components/DocumentHeaderCard.swift:13`, `DocumentUploadSheet.swift:23` (type emoji spoken before the type name); `Features/Documents/Components/StatisticsCardsRow.swift:26-28` (shows and speaks "Total Storage: Phase 5" when storage is 0); `Features/Documents/Components/DocumentMetadataGrid.swift:12` ("v2" read as letters; label and value are separate elements)
- fix: `.accessibilityLabel(type.label)`; replace "Phase 5" with "—"/"Not available"; combine each metadata item and say "Version 2".

### [Low] Unused shared components carrying latent defects
- category: dark-mode
- confidence: high
- where: `Shared/Components/AppErrorView.swift` (0 call sites; fixed light hex icon backgrounds `AppError.swift:59-136`, `.white.opacity(0.7)` link on gradient `:124`); `Shared/Components/SessionExpiredSheet.swift` (0); `Shared/Components/CardSkeleton.swift`, `ListRowSkeleton.swift` (0; fixed `slate100` fills, each row announces "Loading"); `Shared/Components/AsyncButton.swift:116-119` (`.secondary`/`.destructive` styles have no call sites; `.primary` text on fixed `slate100` would be white-on-white in dark mode); `Shared/Components/Forms/AdaptiveHStackVStack.swift` (0)
- fix: Delete, or fix before first use.

### [Low] iPad shell: shortcut buttons with empty titles; profile row drops the email
- category: voiceover
- confidence: medium
- where: `Shared/Navigation/AdaptiveRootView.swift:65-72` (`Button("")` for ⌘1–⌘6 and ⌘, — the hardware-keyboard shortcut overlay will list them without names); `Shared/Navigation/SidebarView.swift:63-64` (label "Profile: name" replaces name + email), `:47-54` (fixed 32 pt initials circle)
- fix: Give the buttons real titles (they are `.hidden()`); let the row combine naturally.

### [Low] Minimum frames applied outside the button rather than inside its label
- category: hit-target
- confidence: low
- where: `Features/Events/Components/EventDetail/CoachesPresentSection.swift:52-60`; `Shared/Components/InlineErrorView.swift:34-36`; `Features/Documents/Components/DocumentVersionRow.swift:38-44`; `Features/Offers/Components/ScholarshipCalculatorView.swift:86-96`; `Features/Offers/Components/AddOfferForm.swift:98-101`; `Features/Events/Components/EventDetail/EventMetricForm.swift:48-61`; `Features/Documents/Views/DocumentViewerView.swift:301-315`
- what: `Button { … }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` pads the layout but may not enlarge the tappable label.
- fix: Move the frame/contentShape inside the `label:` closure, as `Toast.swift:27-31` and `EventsCalendarView.swift:40-42` do.

### [Low] Stepper puts its value in the label
- category: voiceover
- confidence: low
- where: `Features/Offers/Components/AddOfferForm.swift:42-43`
- what: `.accessibilityLabel("Scholarship percentage, \(pct) percent")` with no `accessibilityValue`; `DocumentUploadSheet.swift:45-47` does it correctly.
- fix: `.accessibilityLabel("Scholarship percentage").accessibilityValue("\(pct) percent")`.

### [Low] Fixed-size decorative circles and icons beside scalable text
- category: dynamic-type
- confidence: medium
- where: `Features/Events/Components/EventDetail/EventCoachCard.swift:6, 45-49` (36 pt circle, `.caption` initials); `Shared/Navigation/SidebarView.swift:47-54`; `Features/Documents/Components/DocumentListViewRow.swift:57-59` (80×60 thumbnail); `.font(.system(size:))` at `Shared/Components/EmptyStateView.swift:47`, `Shared/Components/SessionExpiredSheet.swift:15`, `Features/Documents/Components/DocumentCardView.swift:49` (all three already scale via `sizeCategory`/`@ScaledMetric`, so these are acceptable instances of the 37 app-wide)
- fix: `@ScaledMetric` for the circle sizes.

---

## Design tokens

Where colours are defined
- `Core/Theme/AppColors.swift` — the only `extension Color` for app-wide tokens (one `fileprivate` one in `Features/PublicProfile/Models/HeaderColor.swift:44`).
  - `Color.Brand.*` raw palette (`:9-53`), hex, not adaptive: blue 100/500/600/700, emerald 100/500/600/700/800, orange 100/500/600/700/800, purple 100/500/600/700, red 100/500/600/700, slate 100/500/600/700, pink500, sky500, fuchsia500, indigo 100/500/600/700.
  - `Color.Semantic.*` (`:56-62`): actionPrimary = blue600, success = emerald600, warning = orange600, danger = red600, muted = slate500.
  - Legacy aliases (`:68-93`). Adaptive (`Color(light:dark:)`): `darkSlate` (#334155 / #cbd5e1), `secondaryText` (#64748b / #94a3b8), `tertiaryText` (#475569 / #94a3b8), `nearBlack` (#0d0d1a / #f2f2f7), `amberGold` (#b45309 / #fbbf24), `iconGray` (#64748b / #94a3b8), `borderGray`, `warningBannerTitle/Body`, `successBannerIcon/Text`. **Not adaptive**: `accentBlue` (#2563eb), `errorRed` (#dc2626), `successGreen` / `primaryGreen` (#059669), `darkEmerald` (#047857), `warningOrange` (#c2410c), `strengthOrange` (#f97316), `errorBackground` (#fee2e2), `errorBorder` (#fecaca), `warningBackground` (#ffedd5), `warningBorder` (#fed7aa).
  - `Color.Surface.*` (`:98-110`), adaptive: background #F4F6FA / #121212, card #FAFBFD / #1E1E1E, muted #E8EDF5 / #2A2A2A, border, borderStrong, warningTint #FFFBEB / #3A2A0A, warningAccent, warningCTA, successTint #F0FDF4 / #0F2E1C, successAccent.
  - `Color.Text.*` (`:113-117`), adaptive: primary #0F1523 / #FFFFFF, secondary #3A4560 / #CCCCCC, muted #7A8BA0 / #888888.
- `Core/Theme/AppGradients.swift` — `primaryBackground` (emerald500→700), `landingBackground` (emerald500→600), `primaryButton` (blue500 #3b82f6 → blue700 #1d4ed8, leading→trailing).
- `Core/Theme/View+BrandShadow.swift` — shadow colour rgb(30,50,100) at 6–12 %.
- `Shared/Components/BadgeColor.swift` — pill vocabulary: background = Brand *100, foreground = Brand *700, indicator = Brand *500 (blue/emerald/orange/purple/red/slate). Not adaptive.
- `Shared/Components/ToastType.swift:18-25` — icon colours successGreen / errorRed / accentBlue / #F59E0B.
- `Shared/Components/AppError.swift:59-136` — per-error icon hex pairs (component unused).
- Asset catalog: `Assets.xcassets/AccentColor.colorset/Contents.json` is **empty** (no colour values), so `Color.accentColor` / default tint is system blue. There are no other colour sets.

Fonts
- No `Font` extension and no custom fonts. Everything uses semantic text styles; `.font(.system(size:))` appears 3 times in this area, all scaled by `sizeCategory` / `@ScaledMetric`.

Most common text/background combinations (app-wide counts from grep)
- `.foregroundStyle(.secondary)` (407) / `.tertiary` (24) on `Color(.secondarySystemBackground)` (34), `Color(.secondarySystemGroupedBackground)` (12), `Color.Surface.card` (52), system list backgrounds.
- `Color.secondaryText` (97) on `Surface.card` / `Surface.background` / system backgrounds — my arithmetic: #64748b is ~4.8:1 on white, ~4.6:1 on #FAFBFD, ~4.4:1 on #F4F6FA (borderline).
- `Color.darkSlate` (46) on `Surface.card`.
- `Color.Text.muted` (16) on `Surface.card` / `Surface.background` — #7A8BA0 on white is ~3.5:1 by my arithmetic.
- `Color.accentBlue` (126) as text/icon on white, `Surface.card`, and on `accentBlue.opacity(0.12)` chips (`FilterChip`, `FilterMenuButton`); in dark mode on #1E1E1E it is ~3.2:1.
- `Color.errorRed` (62) as text on `Surface.card` / `secondarySystemBackground` and on `Brand.red100`; ~4.8:1 on white, ~4.0:1 on red100, ~3.5:1 on #1E1E1E.
- `Color.successGreen` (39) / `primaryGreen` (26) as text and as button fill with white text; #059669 vs white is ~3.8:1.
- White text on `LinearGradient.primaryButton` (12): ~3.7:1 at the blue500 end, ~6.7:1 at the blue700 end (`AsyncButton` primary, callout semibold).
- White text on `Color.blue` (26 uses of `Color.blue`) and on `Color.red` (11): system blue ~4.0:1, system red ~3.6:1.
- System colours as text: `.foregroundStyle(.red)` (35), `.green` (18), `.blue` (15), `.orange` (7) — usually caption size on white or on a 10–20 % tint of the same colour.
- `BadgeColor` 700 on 100 (`BadgeView`, 9 call sites): roughly 4.6–5.5:1, same in dark mode because neither side adapts.
- White `.foregroundStyle(.white)` (82): on gradients, `Color.blue`, `Color.red`, `secondaryText` (offline banner), status-colour circles.

All ratios above are hand-calculated approximations for the reviewer to recompute.

---

## Done well
- `AsyncButton` (`Shared/Components/AsyncButton.swift`): 48/56 pt min height by size category, label and hint swap while loading, press animation gated on Reduce Motion, multi-line titles allowed.
- `ToastModifier` and `ShimmerModifier` gate their motion on `accessibilityReduceMotion`; `EventsListView.swift:166-170` gates the scroll animation.
- `EmptyStateView` / `ListEmptyState` / `LoadingStateView` / `InlineErrorView`: icons hidden, text wraps (`fixedSize(vertical:)`), 44 pt actions, spinner labelled with the visible message.
- `FilterMenuButton`: 44 pt min height, chevron hidden, button trait, active state in the label.
- `KeyboardFieldNavigation`: labelled Previous/Next/Done keyboard toolbar for numeric keypads (used by both offer forms).
- `SectionHeader`, `InfoRow`, `DetailGridItem`, `WarningBanner`, `BadgeView`, `FilteredResultsHeader`: sensible combined labels, decorative icons hidden.
- `SchoolLogoAvatar`, `EmptyStateView`, `AnalyticsCard`, `DocumentCardView`: sizes step up for accessibility categories.
- Toolbar icon buttons consistently have labels, hints and 44 pt frames (`EventsListView:46-55`, `DocumentsListView:43-52`, `OffersListView:63-85`, `DocumentViewerIconButton`).
- Selection state done correctly in `DocumentFilterBar.swift:66-79` and `DocumentFilterSheet.swift:23-24` (`.isSelected`), and `OfferCard.swift:28-31` (value).
- Status is never colour-only on badges: event type/status, offer status, deadline urgency ("Overdue", "Deadline Soon") and document "Shared: n" all carry text; `OfferFinancialSummary` adds "Urgent/Critical/Overdue" to the spoken label.
- Document viewer offers button alternatives to both gestures (chevrons for swipe-between-documents, Close for drag-to-dismiss) while the toolbar is visible.
- Destructive actions go through confirmation dialogs/alerts; list swipe-to-delete in Events is backed by a menu action in the detail view; offers and documents have explicit delete buttons.
- Required fields are spoken ("…, required") even where the visual marker is only an asterisk.
- No hard-coded `Color.white`/`.black` page backgrounds in this area apart from the deliberately black document viewer.

## Needs simulator verification
- VoiceOver on a video document: after the 3 s auto-hide, can the controls be brought back or the viewer closed at all? (Blocker finding.)
- VoiceOver on Add Coach / Add School: with `FormFieldWrapper`'s `.combine`, can each field be focused and edited, is the typed value read back, and are the tag add/remove buttons reachable?
- Document viewer: does the top-toolbar background really cover the whole screen, and is "Retry" on the error overlay white-on-white?
- Offers list: how VoiceOver/Voice Control present the `NavigationLink` that contains the checkbox and delete buttons; whether tapping the inner buttons also navigates.
- Whether `.frame(minWidth: 44, minHeight: 44)` applied outside a `Button` enlarges its touch area (Low finding list).
- Effect of `accessibilityLabel` on non-element containers (`EventsCalendarView:33`, `OfferEditForm:156`).
- Largest accessibility text size on: Offer detail (financial summary, calculator breakdown), Document detail header buttons, Events calendar grid, Offers filter bar, `InfoRow`.
- Whether the numeric keypad can be dismissed in the scholarship calculator, Create/Edit Event cost and the metric form.
- Measured contrast for the Design-token pairs, in light and dark, and with Increase Contrast on.
- `CoachesPresentSection` rows contain two `Link`s and a `Button` in one `List` row — check that each is individually tappable and focusable.
- A separate checkout at `.claude/worktrees/a11y-audit` differs from the audited tree in `Shared/Components/Layout/AdaptiveDetailLayout.swift` and adds `Shared/Components/Layout/FoldSplit.swift`; those versions were not reviewed.
