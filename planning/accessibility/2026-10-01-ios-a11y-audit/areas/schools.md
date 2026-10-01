# Accessibility findings — Schools, Suggestions, VideoLinks

> **Correction (2026-10-01):** the finding "School card and coach row nest buttons inside a `Button` label" was checked on the simulator and does **not** apply to the Schools list: the card exposes one button with a full label plus separate Delete and Add to favorites buttons. The coach rows inside school detail were not checked. See `../README.md`.

Scope: `Features/Schools/` (all 44 view files read in full), `Features/Suggestions/`, `Features/VideoLinks/`, plus the
shared components those views render (`Shared/Components/*`, `Features/Coaches/Components/CoachCardView.swift`,
`Features/Documents/Components/DocumentCardView.swift`, `Features/Interactions/Components/AnalyticsCard.swift`).
Static read only — nothing was built or run. Paths are relative to the source root in the brief.

Counts: Blocker 0 · High 5 · Medium 10 · Low 9. Two of the Highs (H1, H2) would be Blockers if the simulator
confirms them; they are marked `confidence: medium` for that reason.

---

## High

### [High] Form fields wrapped in `.accessibilityElement(children: .combine)` — text entry may be unreachable with VoiceOver
- category: voiceover / forms
- confidence: medium (the code is certain; the runtime effect on `TextField`/`TextEditor`/`Picker` must be confirmed in the simulator — Blocker if confirmed)
- where: `Shared/Components/Forms/FormFieldWrapper.swift:55-56` (root cause), used by every field of Add School:
  `Features/Schools/Presentation/Views/Components/SchoolFormView.swift:94, 155, 179, 203, 232, 257, 311, 334, 360, 412`;
  same pattern in `Features/Schools/Presentation/Views/Components/SchoolCoachingPhilosophySheet.swift:115-117`
- what: the wrapper collapses label + control + error into one element and overrides its label:
  `.accessibilityElement(children: .combine)` / `.accessibilityLabel(buildAccessibilityLabel())`. The child is an editable
  control (`TextField`, `TextEditor`, menu `Picker`). The per-field labels and hints set inside
  (`"School name, required"`, `"Enter the school's full name"`, …) are discarded by the override, and a merged element
  does not carry the text-input behaviour of the underlying field. In `PhilosophyField` the `TextEditor` is merged the
  same way and its value is replaced with a static `accessibilityValue(text.isEmpty ? "Empty" : text)`.
- user impact: a VoiceOver user may land on "School Name, required" as a non-editable element and be unable to type a
  school name, or pick Division/Status — i.e. unable to add a school manually or edit coaching philosophy.
- fix: do not combine around interactive controls. Hide the visual label (`Text(label).accessibilityHidden(true)`), leave
  the control as its own element with `.accessibilityLabel(label)` (+ `", required"`), and attach the error with
  `.accessibilityValue`/`.accessibilityHint` on the control or keep `FieldError` as a following element. Note the project
  CLAUDE.md rule "Form fields grouped with `.accessibilityElement(children: .combine)`" encourages this pattern and
  should be reworded to apply to read-only label/value rows only.

### [High] School card and coach row nest buttons inside a `Button` label — either the inner actions or the row action is lost to VoiceOver
- category: voiceover
- confidence: medium (needs simulator check for which of the two failure modes occurs)
- where: `Features/Schools/Presentation/Views/SchoolsListView.swift:177-191` wrapping
  `Features/Schools/Presentation/Views/Components/SchoolCardView.swift:37, 62, 64-79`;
  `Features/Schools/Presentation/Views/Components/SchoolCoachesPanel.swift:65-75` wrapping
  `Features/Coaches/Components/CoachCardView.swift:43-47`
- what: the whole card is the label of `Button { navigationPath.append(.detail(school.id)) }`, and that label contains
  `FavoriteStarButton` and the trash `Button`, with `.accessibilityElement(children: .contain)` on the card. Either the
  outer button flattens everything (favourite and delete become unreachable — there are 0 `accessibilityAction`s
  app-wide to replace them), or `.contain` wins and the card is exposed as up to 10 separate stops (name, location,
  favourite, delete, division, status, fit, size, conference, notes) with no element that carries the button trait for
  "open school". Same structure for coach rows on the detail screen (row button containing email/text/call/X/Instagram
  buttons).
- user impact: on the main Schools list a VoiceOver or Voice Control user cannot reliably do all three of open,
  favourite and delete a school; at best navigation is ~10 swipes per school.
- fix: make the card one element: `.accessibilityElement(children: .ignore)`, a composed label
  ("Stanford University, Stanford CA, D1, Contacted, Strong fit"), `.accessibilityAddTraits(.isButton)`,
  `.accessibilityValue(isFavorite ? "Favorite" : "")`, and
  `.accessibilityAction(named: "Add to favorites") {…}` / `.accessibilityAction(named: "Delete") {…}`. Structurally,
  move favourite/delete out of the button label (overlay or sibling `HStack`) so touch and Voice Control targets do not
  overlap.

### [High] Toasts are never announced and auto-dismiss after 3 seconds
- category: voiceover / timing
- confidence: high
- where: `Features/Schools/Presentation/Views/SchoolsListView.swift:104-109`,
  `Features/Schools/Presentation/Views/SchoolDetailView.swift:217-222` (set at `:194-201`);
  root cause `Shared/Components/ToastModifier.swift:19-24` and `Shared/Components/Toast.swift:39-41`
- what: `.toast(isShowing:message:type:duration: 3.0)` overlays a view and dismisses it with
  `try? await Task.sleep(for: .seconds(duration)); dismiss()`. Neither `Toast` nor `ToastModifier` posts an
  `AccessibilityNotification.Announcement`; the only a11y treatment is `.accessibilityAddTraits(.updatesFrequently)`,
  which does not announce. No Schools list/detail view model posts announcements (only `AddSchoolViewModel` has an
  `announcer`).
- user impact: VoiceOver users never learn that a school was deleted or that logging an interaction auto-advanced the
  recruiting status; slow readers and Switch Control users lose the message after 3 s with no way to extend it.
- fix: in `ToastModifier`, `.onAppear { AccessibilityNotification.Announcement(message).post() }`; when
  `UIAccessibility.isVoiceOverRunning`/Switch Control is on, skip the auto-dismiss (or lengthen to ≥ 10 s) and leave
  the existing dismiss button.

### [High] Personal Fit strength is conveyed by badge colour only
- category: color
- confidence: high
- where: `Features/Schools/Presentation/Views/Components/PersonalFitCard.swift:37` with colour map at `:51-59`
- what: `BadgeView(text: signal.label, color: signal.strength.badgeColor)` — the badge text is the signal *name*
  ("Location", "Campus Size", "Cost"); strong / good / stretch exists only as emerald / orange / red. The row is
  `.accessibilityElement(children: .combine)` (`:47`) so VoiceOver reads "Location, In-state, <explanation>" with no
  strength either. (`AcademicFitCard.swift:55` does this correctly: badge text is `strength.label`.)
- user impact: colour-blind users and VoiceOver users cannot tell which fit signals are strong and which are a stretch,
  on the feature that explains whether a school fits.
- fix: add a strength label to `FitSignalStrength` ("Strong", "Good", "Stretch", "No data") and render it as text
  (e.g. badge text "Location · Strong", or an icon + text chip); include it in the row's accessibility label.

### [High] "Clear all" in the active-filter row is white text on the light grouped background
- category: color
- confidence: medium (code is unambiguous; confirm with a light-mode screenshot)
- where: `Shared/Components/FilterChipContainer.swift:42-58` as used by
  `Features/Schools/Presentation/Views/Components/SchoolActiveFilterChips.swift:9-18` (the only `.filled` caller)
- what: for `.filled`, `clearAllColor` returns `.white`; the button has no background of its own and the container is
  `.background(Color(.systemGroupedBackground))` — white on #F2F2F7 in light mode, roughly 1.1:1.
- user impact: sighted and low-vision users in light mode cannot see the "Clear all" control at all (it is readable in
  dark mode and still reachable by VoiceOver).
- fix: `.filled` should use `Color.accentBlue` for the clear button (or give it a filled capsule background).

---

## Medium

### [Medium] School detail: async results and inline errors are not announced
- category: voiceover
- confidence: high
- where: `Features/Schools/Presentation/Views/Components/CollegeDataSection.swift:40-51` (lookup error),
  `AcademicFitCard.swift:36-38` (enrich error), `SchoolRecruitingStatusAndTierSection.swift:16-20` +
  `SchoolStatusStepper.swift:43-45` (status change), `SchoolProsConsSection.swift:38-40, 44-46, 83-85, 89-91` (pro/con
  added or removed), `SchoolDetailView.swift:52` + `Shared/Components/SaveStatusView.swift:16-31` ("Saving…/Saved" in
  the nav bar), `SchoolsListView.swift:152-156` (result count after a filter change),
  `AddSchoolView.swift:192-196` ("N more characters needed")
- what: these states only change text on screen. There is no `AccessibilityNotification` and no
  `@AccessibilityFocusState` anywhere in the detail or list flow (the Add School flow, by contrast, announces through
  `announcer`).
- user impact: after "Lookup" fails, a status change, or applying a filter, a VoiceOver user hears nothing and must
  hunt for what changed.
- fix: post announcements from `SchoolDetailViewModel`/`SchoolsListViewModel` via the existing
  `AccessibilityAnnouncing` protocol ("Status set to Visiting", "Lookup failed: …", "12 schools"); move VoiceOver focus
  to inline errors with `@AccessibilityFocusState`.

### [Medium] Section headings missing the header trait
- category: voiceover
- confidence: high
- where: `SchoolCoachesPanel.swift:25` ("Coaches"), `SchoolCoachingPhilosophySection.swift:20`,
  `SchoolDocumentsSection.swift:79`, `PersonalFitCard.swift:9`, `AcademicFitCard.swift:12`,
  `CollegeScorecardDataDisplay.swift:22`, `SchoolProsConsSection.swift:24, 69` ("Pros"/"Cons"),
  `SchoolDetailHeader.swift:89` (school name — the real title of the screen; the nav title is the generic
  "School Details")
- what: e.g. `Label("Coaches", systemImage: "person.2").font(.headline)` with no `.accessibilityAddTraits(.isHeader)`,
  while sibling sections ("Contact & Social", "College Data", "Quick Actions", "Status History", "School Fit") do set it.
- user impact: heading-rotor navigation on the ~15-section detail screen skips half the sections.
- fix: add `.accessibilityAddTraits(.isHeader)` to each.

### [Medium] Accessibility labels that do not contain the visible text (Voice Control) or name the control type
- category: voice-control
- confidence: high
- where: `SchoolFilterBar.swift:57-64, 81-88, 105-112` (visible "D1" / "Contacted" / "CA", name "Division filter" etc.),
  `SchoolFilterBar.swift:161-167` (visible "Sort: Name", name "Sort order"),
  `SchoolNotesSection.swift:34-37` (visible "Done", name "Dismiss keyboard"),
  `SchoolCoachesPanel.swift:114-119` (visible "Add Coach", name "Add a coach to this school"),
  `Features/VideoLinks/Views/AddEditVideoLinkView.swift:33, 39, 43` ("Platform picker", "Video URL field",
  "Title field"), `SchoolProsConsSection.swift:42, 87` ("Add pro input"), `SchoolNotesSection.swift:42`
  ("Notes text editor")
- what: no `accessibilityInputLabels` anywhere in the area, so a Voice Control user saying what they see
  ("Tap D1", "Tap Done", "Tap Add Coach") gets no match; several labels also append the control type, which VoiceOver
  then reads twice ("Platform picker, picker").
- user impact: Voice Control users must fall back to numbers/grid for the filter bar and keyboard dismissal.
- fix: start each label with the visible text or add `.accessibilityInputLabels(["D1", "Division"])`; drop
  "field/picker/input/text editor" from labels.

### [Medium] Hit targets under 44 pt — `frame` applied outside the `Button`, and unframed text/icon buttons
- category: hit-target
- confidence: medium (sizes inferred from fonts; measure in the simulator)
- where: frame outside the button, so only the glyph is tappable: `FavoriteStarButton.swift:8-13`,
  `ProItem.swift:18-23`, `ConItem.swift:18-24` (caption-size ×, ~12 pt), `SchoolProsConsSection.swift:44-60, 89-105`,
  `CollegeDataSection.swift:22-36`. No minimum size at all: `SelectedCollegeCard.swift:62-69`,
  `SchoolCoachesPanel.swift:32-36, 42-46, 113-118` (`.controlSize(.small)`),
  `SchoolBasicInfoDisplaySection.swift:62` and `SchoolCoachingPhilosophySection.swift:26-30` ("Edit"),
  `SchoolDocumentsSection.swift:85-93` ("Upload"), `SchoolStatusStepper.swift:43-66` (28 pt circle in a ~38 pt column),
  `:96-99` ("Reactivate"), `:107-112` ("Mark not pursuing"), `AcademicFitCard.swift:27-33`, contact `Link`s at
  `SchoolBasicInfoDisplaySection.swift:79, 35, 109, 159, 182`; shared `Shared/Components/FilterChip.swift:31-39`
  (24×24) and `FilterChipContainer.swift:42`
- what: e.g. `Button(action: onRemove) { Image(systemName: "xmark.circle.fill").font(.caption) }.frame(minWidth: 44, minHeight: 44)`
  — the frame enlarges layout, not the button's hit region.
- user impact: users with motor impairments mis-tap small remove/edit controls; remove-pro sits next to the row text.
- fix: put `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` on the label *inside* the button (as
  `SchoolCardView.swift:74-75` and the list toolbar already do).

### [Medium] Status stepper does not survive large text
- category: dynamic-type
- confidence: medium
- where: `Features/Schools/Presentation/Views/Components/SchoolStatusStepper.swift:29-37, 57-64, 144`
- what: five nodes plus four connectors share one `HStack`, so each label column is ~38 pt wide on an iPhone; labels
  are `.caption2` with `.fixedSize(horizontal: false, vertical: true)`, so "Researching"/"Committed" wrap
  mid-word character-by-character at accessibility sizes. The check glyph is `.font(.system(size: 12, weight: .bold))`
  inside fixed 28 pt circles.
- user impact: at AX sizes the pipeline labels become a column of letters; the primary status control is hard to read.
- fix: branch on `dynamicTypeSize.isAccessibilitySize` to a vertical list (or a `Picker`/menu) of stages; use
  `@ScaledMetric` for the node size and a text-style font for the glyph.

### [Medium] Multi-column layouts and truncation that cannot reflow at accessibility text sizes
- category: dynamic-type
- confidence: medium
- where: `SchoolProsConsSection.swift:21-111` (two side-by-side columns each holding a text field + 44 pt button),
  `SchoolQuickActions.swift:16-50, 79-85` (three buttons across, `.caption`, `lineLimit(2)`),
  `CollegeScorecardDataDisplay.swift:28-34` and `SchoolDocumentsSection.swift:101-104` (fixed two-column grids;
  `DocumentCardView.swift:23, 80` truncates title/metadata), `SchoolDetailHeader.swift:89-93`
  (`.lineLimit(2).minimumScaleFactor(0.9)` on the school name beside a fixed 56 pt logo), `SchoolAnalyticsCards.swift:7-12`,
  `Shared/Components/InfoRow.swift:9-19` and the contact rows in `SchoolBasicInfoDisplaySection.swift:29-47, 73-85, 103-125`
  (label and value squeezed side by side; URLs `lineLimit(2)` middle-truncated)
- what: no `dynamicTypeSize` branch or `ViewThatFits` in any of these (the add-school form's `AdaptiveHStackVStack`
  is the one place that reflows).
- user impact: at AX3–AX5 pros/cons become ~3 words per line, quick-action titles truncate, and long school names are
  cut off with no other place to read them.
- fix: wrap in `ViewThatFits`/`AnyLayout` switching to `VStack` at `dynamicTypeSize.isAccessibilitySize`; make grids
  single-column at accessibility sizes; remove the line limit and scale factor from the school name.

### [Medium] Likely contrast failures — coloured and tertiary text carrying real information
- category: color
- confidence: medium (ratios estimated from system colour values; measure in both schemes)
- where: `.tertiary` text: `SchoolCoachesPanel.swift:107-109`, `SchoolCoachingPhilosophySection.swift:152-154`,
  `SchoolDocumentsSection.swift:137-139`, `SchoolMapView.swift:97-99`, `StatusHistoryRow.swift:33-35` (the date of
  each change), `SchoolCoachingPhilosophySheet.swift:106-107`. Green text: `SchoolProsConsSection.swift:24-27`
  ("Pros" on systemGray6), `SelectedCollegeCard.swift:52-54` (caption on a green tint),
  `DocumentCardView.swift:85-90`. Red text: `SchoolProsConsSection.swift:69-72`, `AcademicFitCard.swift:37`. Blue
  caption: `SelectedCollegeCard.swift:41-43`, `AutoFilledBadge.swift:15-17`. White on `Color.blue`:
  `SchoolFilterBar.swift:126-130` (active Favorites chip), `Shared/Components/FilterChip.swift:65-80`. Favourite star
  `.yellow` on white: `FavoriteStarButton.swift:10`, `SchoolDetailView.swift:59-60` (non-text, needs 3:1)
- what: e.g. `Text("Use 'Lookup College Data' to fetch location").font(.caption).foregroundStyle(.tertiary)`; system
  green on light gray is roughly 2:1, tertiary label roughly 2:1, white on system blue roughly 4:1 (below 4.5:1 for
  subheadline).
- user impact: low-vision users cannot read instructional empty-state copy, history dates or success/error lines.
- fix: use `.secondary` for body copy, `Color.Brand.emerald700`/`red700` (already defined) for coloured text, and
  `Color.Brand.blue700` behind white chip text.

### [Medium] Map marked `.allowsDirectInteraction`
- category: voiceover
- confidence: medium
- where: `Features/Schools/Presentation/Views/Components/SchoolMapView.swift:40-48`
- what: `.accessibilityAddTraits(.allowsDirectInteraction)` with hint "Use two fingers to pan and pinch to zoom the
  map" on a full-width, 200 pt-high map inside the scrolling detail screen. Touches beginning on the map bypass
  VoiceOver, and the map exposes nothing but its label.
- user impact: VoiceOver users swiping through the detail screen with a finger over the map move the map instead of
  the cursor, and gain nothing from interacting with it.
- fix: remove the trait; treat the map as an image-like element (label plus the existing distance row), and offer an
  "Open in Maps" button/accessibility action for directions.

### [Medium] Video link rows are editable only through an unlabelled tap gesture
- category: voiceover / voice-control
- confidence: high
- where: `Features/VideoLinks/Views/VideoLinksEditorView.swift:87-93` and `:128-136`
- what: `VideoLinkRow(link: link).contentShape(Rectangle()).onTapGesture { … editingLink = link … }` with no
  `.accessibilityAddTraits(.isButton)` or hint; the row is `.accessibilityElement(children: .combine)` with label
  "\(title): \(health)", so nothing says it can be edited and Voice Control shows no name for it. The label also uses
  `link.title ?? platform` while the visible text treats an empty title as missing (`:116`), so an empty-string title
  reads as ": Working"; the URL is dropped from the label.
- user impact: VoiceOver and Voice Control users are not told a row can be opened for editing.
- fix: make the row a `Button` (or add `.isButton` + `.accessibilityHint("Edits this link")`), reuse the visible
  title logic for the label and include the URL host.

### [Medium] Placeholder-only fields with no persistent label; silent disabled Save
- category: forms
- confidence: high
- where: `Features/Schools/Presentation/Views/Components/SchoolBasicInfoSheet.swift:15-60` (nine fields),
  `Features/VideoLinks/Views/AddEditVideoLinkView.swift:35-44, 20-23, 69`, `SchoolProsConsSection.swift:36, 81`,
  `AddSchoolView.swift:181`
- what: `TextField("Website", text: $info.website)` / `TextField("Athletics Website", …)` /
  `TextField("Twitter Handle", …)` / `TextField("Instagram Handle", …)` in a `Form`. The sheet opens pre-filled, so the
  placeholders are never visible: two URL fields and two handle fields are indistinguishable by sight. In the video
  link form, Save is `.disabled(!isValidURL …)` where `isValidURL` requires a scheme — typing `hudl.com/…` leaves Save
  disabled with no message explaining why; the URL field also lacks `.textContentType(.URL)`. Colours are entered as
  raw hex with an unlabelled swatch.
- user impact: low-vision and cognitive users cannot tell which value they are editing; any user can get stuck on a
  disabled Save.
- fix: use `LabeledContent("Website") { TextField(…) }` (or `FormFieldWrapper` once H1 is fixed); show an inline
  "Enter a full link starting with https://" error (or prepend the scheme) and announce it; use `ColorPicker`.

---

## Low

### [Low] Raw database values are displayed and read aloud
- category: voiceover
- confidence: medium (depends on stored data)
- where: `StatusHistoryRow.swift:16, 27, 55-57` (`entry.previousStatus`/`newStatus` are raw strings such as
  `offer_received`, `not_pursuing`), `SchoolAttributionSection.swift:59-61, 68-69` (`Text("by \(userId)")` — `createdBy`
  is the `created_by` column), `SchoolBasicInfoDisplaySection.swift:150` (colours read as hex strings)
- what: values are shown without mapping through `SchoolStatus(rawValue:)?.displayName` or a member name.
- user impact: VoiceOver reads "offer underscore received" and a 36-character user id.
- fix: map statuses to `displayName`, resolve the user id to a family-member name (or drop it), and label colours as
  "School colors" with names or hide the hex.

### [Low] Progress indicators replace button labels without a label; decorative status icons not hidden
- category: voiceover
- confidence: high
- where: `SchoolBasicInfoSheet.swift:81-83`, `AddEditVideoLinkView.swift:63-64`, `SchoolDocumentsSection.swift:26`,
  `SchoolStatusStepper.swift:90-91` (pause icon), `Shared/Components/SaveStatusView.swift:18, 26`
- what: `if isSaving { ProgressView() } else { Text("Save") }` with no `.accessibilityLabel`.
- user impact: the Save button loses its name while saving; stray "image" stops.
- fix: add `.accessibilityLabel("Saving")` on the button; `.accessibilityHidden(true)` on the icons.

### [Low] Wrong traits and gesture instructions baked into labels
- category: voiceover
- confidence: high
- where: `AddSchoolView.swift:159-162` (`Toggle` + `.accessibilityAddTraits(.isButton)`),
  `SchoolBasicInfoDisplaySection.swift:49, 87, 127, 169, 200` ("… Tap to open." inside the label, including the
  non-link fallback branches at `:44, 82, 121, 194`), `SchoolFilterBar.swift:65, 89, 113, 135, 168`,
  `SchoolCardView.swift:78`, `FavoriteStarButton.swift:15`, `ConItem.swift:26` ("Double tap to …" hints),
  `ProItem.swift:24` vs `ConItem.swift:25` (inconsistent "Remove X" / "Remove con: X"),
  `SchoolFilterBar.swift:220-221` (the only actionable instruction is in the hint),
  `CollegeScorecardDataDisplay.swift:120` ("✓ Map coordinates available")
- what: instructions belong in `accessibilityHint` and should not name the gesture; the label claims "Tap to open"
  even when no link is rendered.
- user impact: verbose or misleading announcements.
- fix: move to hints without gesture wording; rely on the `Link` trait; drop `.isButton` from the toggle.

### [Low] Contact rows combine a `Link` into a static row
- category: voiceover
- confidence: low
- where: `SchoolBasicInfoDisplaySection.swift:48, 86, 126, 168, 199`
- what: `.accessibilityElement(children: .combine)` on rows whose only interactive child is a `Link`; whether
  activation and the link trait survive the merge needs a device check.
- user impact: if not, phone/website/social links cannot be opened with VoiceOver.
- fix: make the `Link` the element (`Link { row }`), labelled "Website, example.edu".

### [Low] Animations not gated on Reduce Motion
- category: motion
- confidence: high
- where: `SchoolCoachingPhilosophySection.swift:71-73` (`withAnimation(.easeInOut(duration: 0.2))`),
  `Shared/Components/SaveStatusView.swift:8`, `Shared/Components/ToastModifier.swift:31` (dismiss; the transition
  itself is gated at `:18`), `StatusHistoryRow.swift:33` (`Text(date, style: .relative)` ticks every second)
- what: short fades/expansions and a live-updating label.
- user impact: minor.
- fix: `withAnimation(reduceMotion ? nil : …)`; use `.relative(presentation: .named)` formatting as the a11y label does.

### [Low] Text-input configuration
- category: forms
- confidence: high
- where: `SchoolFormView.swift:233-236, 312-315, 335-338`, `SchoolBasicInfoSheet.swift:56-60`
- what: handle and conference fields lack `.autocorrectionDisabled()` / `.keyboardType(.twitter)`; validation runs
  only on Return (`.onSubmit`) for city/state/conference/website/handles.
- user impact: autocorrect mangles handles; errors appear late.
- fix: add the modifiers; validate on focus loss as the name/notes fields do.

### [Low] Custom back button replaces the system one on Add School
- category: voiceover
- confidence: low
- where: `AddSchoolView.swift:82-91`
- what: `.navigationBarBackButtonHidden(true)` with a custom "Back" item; the edge-swipe and possibly the VoiceOver
  two-finger scrub (escape) no longer pop the screen.
- user impact: standard back gestures may not work.
- fix: keep the system back button, or add `.accessibilityAction(.escape) { dismiss() }`.

### [Low] Badges read without context in the list
- category: voiceover
- confidence: high
- where: `SchoolCardView.swift:124-136`
- what: `BadgeView(text: divisionEnum.displayName, …)` reads "D1", "Contacted", "Large" as bare words (the detail
  header's `DivisionBadge`/`StatusBadge`/`SizeBadge` prefix "Division:", "Status:", "Size:").
- user impact: minor ambiguity; resolved by the single-element card label proposed in H2.
- fix: pass `accessibilityLabel:` to `BadgeView`.

### [Low] Unused components carry defects that would ship if revived
- category: voiceover
- confidence: high
- where: `SchoolStatusPickerSection.swift:56-58` (`.combine` over a `Menu`), `BreakdownRow.swift:23-38` (label on a
  `GeometryReader`, score coloured only), `AutoFilledBadge.swift`
- what: none is referenced outside its own preview.
- user impact: none today.
- fix: delete, or fix before reuse.

---

## Done well
- Add School flow announces search results, selection, enrichment, duplicate detection and submit failures through
  `AccessibilityAnnouncing` (`AddSchoolViewModel*.swift`), and `FormErrorSummary` posts an error announcement.
- `SchoolStatusStepper` exposes state in words and traits ("Contacted, completed" / `.isSelected`), hides connectors,
  and distinguishes completed/current/upcoming by shape (check, dot, empty), not colour alone.
- Filter menus, the Favorites chip and the distance `Slider` expose `accessibilityValue`; chips grow to 52 pt at
  accessibility sizes; the filter rows scroll horizontally instead of truncating.
- List toolbar buttons, card delete button, toast dismiss and error-summary dismiss put the 44 pt frame and
  `contentShape` inside the label.
- Decorative icons are consistently `.accessibilityHidden(true)`; loading states use labelled `ProgressView`s
  (`LoadingStateView`); empty states are combined into one element with a real button.
- Semantic text styles are used throughout (one fixed-size font in the area); `SchoolCardView`, `AnalyticsCard`,
  `EmptyStateView` and `QuickActionButton` scale icon sizes with the size category; the add-school form reflows with
  `ViewThatFits`.
- Colours are mostly semantic/system or light-dark pairs (`Color.Surface.card`), so dark mode has no unreadable
  hard-coded surfaces in this area; `VideoLinkRow` health uses distinct icons plus a text label, `AcademicFitCard`
  badges carry text.
- Destructive actions use confirmation dialogs with plain-text messages; required fields are announced as
  ", required" with the asterisk hidden.

## Needs simulator verification
1. H1 — with VoiceOver on, can each Add School field (`FormFieldWrapper`) and each Coaching Philosophy editor be
   focused, edited and read back? Do the Division/Status pickers open?
2. H2 — what VoiceOver exposes for a school card and a coach row: one element or many; are favourite, delete and the
   coach communication buttons reachable; does Voice Control show a name for "open school"?
3. H5 — light-mode screenshot of the active-filter row to confirm "Clear all" is invisible.
4. Whether `Link`s inside combined contact rows still activate (phone, website, social, conference, athletics).
5. Measured hit regions for the buttons whose 44 pt frame sits outside the `Button`.
6. Status stepper, Pros & Cons, Quick Actions and the detail header at AX3 and AX5 on a 375 pt-wide device.
7. Contrast measurements for tertiary/green/red/blue text and white-on-blue chips in light and dark.
8. Map behaviour with VoiceOver (`.allowsDirectInteraction`) while swiping through the detail screen.
9. Whether the two-finger scrub pops Add School with the system back button hidden.
10. What `created_by` and status-history rows contain in production data (UUID vs name; raw vs display status).
11. `SuggestionsListView` is a thin list around `ActionItemCard` (Dashboard area) — its card actions were not
    audited here.
