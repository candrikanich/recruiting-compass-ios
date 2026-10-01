# Accessibility findings — Coaches, Interactions, InboundDrafts, CommunicationTemplates

> **Correction (2026-10-01):** the finding "Coach list card exposes no button for 'open coach details'" was checked on the simulator and does **not** reproduce: the card exposes one button with a full label plus separate Email coach buttons. See `../README.md`.

Scope read in full: every View/Component file under `Features/Coaches/`, `Features/Interactions/`,
`Features/InboundDrafts/`, `Features/CommunicationTemplates/`, plus the view-model paths that drive what is
shown/announced and the shared components these views use (`FormFieldWrapper`, `FilterChip`, `FilterMenuButton`,
`Toast`/`ToastModifier`, `BadgeView`, `DetailGridItem`, `SaveStatusView`, `FormErrorSummary`, `AppColors`).
Static review only — nothing was built or run. Contrast ratios are computed from the hex values in
`Core/Theme/AppColors.swift`.

Not live (only referenced from their own `#Preview`s, so excluded from findings): `CoachMetricsSection`,
`CoachStatisticsSection`, `ContactInfoSection`, `ContactRow`.

Counts: Blocker 1 · High 8 · Medium 12 · Low 8

---

### [Blocker] Interaction content is replaced by the words "Interaction content" for VoiceOver
- category: voiceover
- confidence: high
- where: `Features/Interactions/Views/InteractionDetailView.swift:191-194`
- what: `Text(content).font(.body).textSelection(.enabled).accessibilityLabel(String(localized: "Interaction content"))` — the label overrides the text, so VoiceOver reads the literal string "Interaction content" instead of the message body. The list card's label (`InteractionCard.swift:150-175`) also omits content, so the body is not available anywhere in the Interactions tab.
- user impact: A VoiceOver user cannot read what a logged interaction says; the only partial workaround is the coach-detail log (only when a coach is linked) or exporting.
- fix: Delete the `.accessibilityLabel` (the "Content" header above it already gives context). If a prefix is wanted use `.accessibilityLabel(Text("Interaction content: \(content)"))`.

### [High] Failures on coach detail and interaction detail are never shown or announced
- category: voiceover
- confidence: high
- where: `Features/Coaches/Views/CoachDetailView.swift:58-64`; set at `Features/Coaches/ViewModels/CoachDetailViewModel.swift:281,304,380,458,504,509,543,547`; `Features/Coaches/Components/CoachEditForm.swift` (no error slot); `Features/Interactions/Views/InteractionDetailView.swift:37-42,91-97`
- what: `contentBody` renders `viewModel.errorMessage` only in `else if let error = viewModel.errorMessage` after `if let coach = viewModel.coach`. Once the coach has loaded, "Failed to save tags", "Failed to save notes", "Failed to save changes", "Failed to delete interaction", "Failed to delete coach" are set but never displayed. The edit sheet stays open with no message. Interaction detail has the same shape: a failed delete only fires `hapticErrorTrigger += 1`.
- user impact: Every user loses the error, and a VoiceOver user gets no signal at all (the haptic is the only cue) that notes, tags, edits or deletes did not save.
- fix: Present post-load errors with `.alert` (or the existing `ErrorBanner`) bound to `errorMessage`, pass the save error into `CoachEditForm`, and post `AccessibilityNotification.Announcement(message)` when it is set.

### [High] Quick Communication send warnings appear silently; "Tap Send again" is never heard
- category: voiceover
- confidence: high
- where: `Features/Coaches/Views/QuickCommunicationView.swift:283-288` (warning text), `:296-306` (Send in bottom inset), `:46-55,58,312` (Instagram guardian lock → toast), `:336-340,351-355` (mailto/sms fallback toast); source strings `Features/Coaches/ViewModels/QuickCommunicationViewModel.swift:101,120-135`
- what: Tapping Send runs `evaluateGuardrails`; when it blocks, it sets `sendWarning` ("...Tap Send again to send anyway.") which renders as a `.caption` `Text` inside the ScrollView above, while focus stays on the Send button in the `safeAreaInset`. Nothing is announced and focus does not move. The Instagram path and the mail/SMS fallback use `.toast(... duration: 3.0)`, which posts no announcement and removes itself after 3 seconds.
- user impact: A VoiceOver user taps Send, nothing appears to happen, and they are not told the account is guardian-locked, that the note was reused, or that a second tap is required.
- fix: Post `AccessibilityNotification.Announcement(warning)` whenever `sendWarning` changes (and in `ToastModifier` on appear), or move focus to the warning with `@AccessibilityFocusState`; do not auto-dismiss a toast that carries an instruction.

### [High] Dark mode: system-adaptive text on fixed light pastel backgrounds becomes unreadable
- category: dark-mode
- confidence: high
- where: `Features/Coaches/Components/CoachAlertsSection.swift:39` on `:13,20,45`; `Features/Coaches/Components/CoachStatsGrid.swift:89` on `:103`; `Features/Coaches/Components/CoachCardView.swift:119-122` with `Features/Coaches/Models/CoachRole.swift:20`
- what: `Color.errorBackground` (`#fee2e2`) and `Color.Brand.blue100` (`#dbeafe`) are non-adaptive hex colours, but the text on them is adaptive: `Text(message).font(.footnote).foregroundStyle(.secondary)` in the alert banners and the `.secondary` "DAYS SINCE" label on the overdue card. In dark mode `.secondary` is light grey on a light pastel (about 1.1:1). Separately the role badge draws `.foregroundStyle(.white)` on `role.badgeColor`; `.amberGold` resolves to `#fbbf24` in dark mode, giving about 1.7:1 for "Recruiting Coordinator".
- user impact: In dark mode the "Outreach Overdue" explanation, the overdue card label and the Recruiting Coordinator badge cannot be read.
- fix: Use adaptive surfaces (`Color(light:dark:)` tints like `Surface.warningTint`) or pin a dark text colour on the pastel (`Color.Brand.slate700`); give the role badge a per-role foreground instead of hard-coded white.

### [High] Three-column grids on coach detail truncate at large text sizes
- category: dynamic-type
- confidence: medium
- where: `Features/Coaches/Components/CoachDirectChannelsGrid.swift:15,17-21,51-55`; `Features/Coaches/Components/CoachStatsGrid.swift:10-14,73-74,90-91,96-97`; `Features/Coaches/Components/CoachInteractionsLogSection.swift:143-155`
- what: Both grids are a fixed three `GridItem(.flexible())` layout at every size. Channel labels use `Text(label).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)` (and `sizeCategory` is declared on line 15 but never used); stat values use `.lineLimit(1).minimumScaleFactor(0.6)`, e.g. the "Preferred" value "In-Person Visit". The Shown/Sent/Received tiles are three equal columns in one `HStack`.
- user impact: At accessibility text sizes "Instagram", "Log Activity" and the preferred-channel value shrink and then truncate to a few characters in a roughly 100pt column.
- fix: Switch to one or two columns when `dynamicTypeSize.isAccessibilitySize` (or `ViewThatFits`), and drop `lineLimit(1)`/`minimumScaleFactor` on the value and button labels.

### [High] Coach list card exposes no button for "open coach details"
- category: voiceover
- confidence: medium
- where: `Features/Coaches/Views/CoachesListView.swift:204-221`; `Features/Coaches/Components/CoachCardView.swift:47,74`
- what: The row is `Button { navigationPath.append(.detail) } label: { CoachCardView(...) }` and the card applies `.accessibilityElement(children: .contain)` because it holds its own Email/Text/Call buttons. With `.contain` the name, school, role and contact rows are separate static texts and no element carries a button trait, label or hint for the navigation. (`InteractionCard.swift:16-20` solves the same nesting by combining the content and adding `.isButton` plus a hint; the coach card does not.)
- user impact: A VoiceOver or Voice Control user is never told a coach card opens the detail screen and has no named control to activate for it.
- fix: Mirror `InteractionCard`: wrap header + content in `.accessibilityElement(children: .combine)` with `.accessibilityAddTraits(.isButton)`, `.accessibilityLabel("\(coach.fullName), \(role), \(school)")` and a hint, leaving the channel buttons as siblings.

### [High] Expandable interaction rows do not expose expanded/collapsed state
- category: voiceover
- confidence: high
- where: `Features/Coaches/Components/CoachInteractionsLogSection.swift:203-249` (toggle button), `:242-245` (chevron hidden), `:251-291` (revealed content)
- what: `Button(action: onToggle)` has no `accessibilityValue`/hint, and the only state indicator is `Image(systemName: isExpanded ? "chevron.up" : "chevron.down").accessibilityHidden(true)`. Expanding inserts content, sentiment, attachments and a Delete button with no announcement.
- user impact: VoiceOver users cannot tell that a row expands, whether it is open, or that a Delete button appeared beneath it.
- fix: Add `.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")` and `.accessibilityHint("Shows message details")` to the toggle button, or use `DisclosureGroup`.

### [High] Tag remove button is a 9pt glyph with no hit area
- category: hit-target
- confidence: high
- where: `Features/Coaches/Components/CoachTagsCard.swift:35-41`
- what: `Button { onRemove(tag) } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }` — no frame, padding or `contentShape` on the button; the chip's padding is applied outside it. The tappable area is roughly 9×11pt, below the 24×24 minimum of WCAG 2.5.8 as well as Apple's 44pt, and the fixed size never scales. Removal is immediate with no confirmation.
- user impact: Users with tremor or low dexterity cannot reliably remove a tag, on coach detail and in the add/edit coach forms.
- fix: Give the label `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` (negative padding to keep the chip compact) and use a semantic font such as `.caption2.bold()`.

### [High] Text fields and tag buttons are merged into one combined element
- category: voiceover
- confidence: low
- where: `Features/Coaches/Views/QuickCommunicationView.swift:610-626`; `Features/Coaches/Components/CoachFormView.swift:63-71` via `Shared/Components/Forms/FormFieldWrapper.swift:47-48` (also wraps every field at `CoachFormView.swift:77,109,126,145,163,192,208,226`)
- what: `QuickCommSpecificityField` applies `.accessibilityElement(children: .combine).accessibilityLabel(title)` to a `VStack` containing the `TextField`, and `FormFieldWrapper` does the same around each field. For the Tags field this merges every "Remove tag X" button and "Add tag" under the single label "Tags". Whether the merged element keeps the text-field trait, value and editing activation cannot be determined statically.
- user impact: If the merge drops the text-field semantics, VoiceOver users cannot tell these are editable fields or hear what they typed, and individual tags cannot be targeted.
- fix: Remove `.combine` from the wrappers; hide the visual label with `.accessibilityHidden(true)` and put the full label (with ", required" / error) on the control itself. Keep `CoachTagsCard` as `.contain`.

### [Medium] Accessibility labels differ from the visible text (Voice Control)
- category: voice-control
- confidence: high
- where: `Features/Coaches/Components/CoachFilterBar.swift:39,65,99`; `Features/Interactions/Components/InteractionFilterBar.swift:39,69,99,129,175`; `Features/Coaches/Components/CoachEditForm.swift:153,182`; `Features/Coaches/Views/AddCoachView.swift:60,204`; `Features/Coaches/Views/CoachDetailView.swift:372`; `Features/Coaches/Views/QuickCommunicationView.swift:466`; `Features/Interactions/Views/AddInteractionView.swift:64,148,157,185,213,240,263,278,291,315`; `Features/CommunicationTemplates/Views/CommunicationTemplatesView.swift:138`
- what: Visible "Role" is labelled "Filter by role"; "Type" is "Filter by type"; "Save" is "Save coach changes"; "Set next contact date" is "Toggle next contact date"; "Copy Link" is "Copy profile link"; "DM on Instagram" is "Open Instagram profile @…"; "School not listed? Add it" is "Add a school not in the list"; "Email (3)" is "Filter by Email, 3 templates". None set `accessibilityInputLabels`.
- user impact: Voice Control users who say the name they see ("Tap Role", "Tap Save") get no match and must fall back to numbers or the grid.
- fix: Start each label with the visible text and move the extra context to `accessibilityHint`/`accessibilityValue`, or add `.accessibilityInputLabels(["Role", "Filter by role"])`.

### [Medium] Tappable targets under 44pt
- category: hit-target
- confidence: high
- where: `Features/Coaches/Components/CoachDetailHeader.swift:91-101,107-118,129`; `Features/Coaches/Components/CoachCardView.swift:246`; `Features/Coaches/Components/CoachInteractionsLogSection.swift:21-22,131-139,283-288`; `Features/Coaches/Components/CoachTagsCard.swift:50-56`; `Features/Coaches/Views/CoachDetailView.swift:357-371`; `Features/CommunicationTemplates/Views/CommunicationTemplatesView.swift:130-136`; `Features/CommunicationTemplates/Views/TemplateEditorView.swift:119-130`
- what: Edit/Delete coach are `.frame(width: 36, height: 36)` side by side; email/phone/social rows are one `.subheadline` line tall; card quick-comm icons are `minWidth: 36`; the log's "Clear" is bare `.footnote` text, filter menus are footnote + 6pt padding (about 30pt), Delete is `.controlSize(.small)`; "Add Tag" and "Copy Link" are bare footnote/caption labels; template filter pills and variable chips are caption text with 6–8pt padding.
- user impact: Motor-impaired users mis-tap, most seriously on the adjacent Edit/Delete pair and the destructive Delete in the log.
- fix: Add `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` to each label (as `CommunicationButton.swift:37` and `InteractionCard.swift:42` already do).

### [Medium] Text contrast below WCAG AA
- category: color
- confidence: medium
- where: `Features/Coaches/Components/CoachDirectChannelsGrid.swift:26-40,57`; `Features/Coaches/Components/CoachStatsGrid.swift:33,53,64`; `Features/Coaches/Components/CoachCardView.swift:119-122`; `Features/Coaches/Components/CoachInteractionsLogSection.swift:148-153`; `Features/Coaches/Components/CoachAlertsSection.swift:38-39`; `Features/CommunicationTemplates/Components/TypeBadgeView.swift:9-12`; `Features/Interactions/Components/InteractionPrivacyNotice.swift:13,19`; `Features/Coaches/Views/QuickCommunicationView.swift:205,274,280,286,727`; `Features/Coaches/Components/CoachDetailHeader.swift:35,61`; `Features/Coaches/Components/CoachTagsCard.swift:55`; `Features/Coaches/Components/CoachEditForm.swift:32,45,69,82,96,109`
- what: White 15pt-semibold labels on `emerald500` (2.5:1), `orange500` (2.8:1), `sky500` (2.8:1), `blue500` (3.7:1); white caption on `red500` "OVERDUE" (3.8:1) and on `successGreen` Assistant badge (3.8:1); `emerald600` on `emerald100` (3.3:1) and `blue600` on `blue100` (4.2:1) caption text; `.secondary` on `red100` (about 3.2:1); `.cyan` on its own 15% tint; `.blue.opacity(0.9)` on blue 10%; `.tertiary` caption2 "Ask the athlete to answer these." In dark mode the non-adaptive `accentBlue`, `errorRed` and `warningOrange` text tokens drop to about 3.3–3.5:1 on dark surfaces, which includes the send warnings and validation errors.
- user impact: Low-vision users struggle to read channel button labels, status pills, badges and warning text.
- fix: Use the 700-level foregrounds from `BadgeColor` on 100-level tints, darken the channel fills to the 600/700 shades, and make `accentBlue`/`errorRed`/`warningOrange` adaptive with lighter dark-mode values.

### [Medium] Form fields with placeholder-only or no visible label
- category: forms
- confidence: high
- where: `Features/Coaches/Components/CoachEditForm.swift:23,36,59,73,87,100,115`; `Features/Interactions/Views/AddInteractionView.swift:273,288`
- what: The edit form uses `TextField("First Name", text:)` etc. with no persistent label; because the form opens pre-filled, the screen shows only values, and the two "Social Media" rows (`"Twitter Handle"`, `"Instagram Handle"`) are indistinguishable once filled. In Log Interaction, Subject is placeholder-only and the Content `TextEditor` has no visible label or placeholder at all under "Details (Optional)".
- user impact: Low-vision and cognitive-disability users cannot tell which field is which after text is entered; Voice Control users have no visible name to speak.
- fix: Use `LabeledContent("Twitter", ...)` or a visible caption above each field (as `CoachFormView` does via `FormFieldWrapper`), and add a visible "Notes"/"Content" label for the editor.

### [Medium] Section titles are not headings
- category: voiceover
- confidence: high
- where: `Features/Coaches/Components/SectionCard.swift:12-16`; `Features/Coaches/Components/NotesSection.swift:18-20`; `Features/Coaches/Components/CoachAnalyticsCard.swift:18`; `Features/Coaches/Views/QuickCommunicationView.swift:525,556`; `Features/Interactions/Views/AddInteractionView.swift:329`
- what: `SectionCard`'s label (`Text(label).font(.caption.bold()).textCase(.uppercase)`) has no `.isHeader`, so "Direct Channels", "Interactions History", "Send Recruiting Profile", "Internal Notes", "Tags", "Profile Meta" are plain text; likewise "Shared Notes", "Use a template", the template stage group titles and "Coach Interest Level".
- user impact: VoiceOver users cannot use the Headings rotor to move through the long coach detail screen or the template picker.
- fix: Add `.accessibilityAddTraits(.isHeader)` to those `Text`s (one line in `SectionCard` covers six sections).

### [Medium] Ambiguous or uninformative control labels
- category: voiceover
- confidence: high
- where: `Features/Coaches/Components/CoachCardView.swift:195,210`; `Features/Coaches/Components/CommunicationType.swift:43-47`; `Features/Coaches/Components/CoachDetailHeader.swift:102,119`; `Features/Interactions/Components/InteractionCard.swift:12`; `Features/Coaches/Views/QuickCommunicationView.swift:466`
- what: Every card in the list repeats "Email coach" / "Text coach" / "Call coach" with no name. In the detail header `.accessibilityLabel(text)` makes the email and phone buttons read only the address/number with no action, and both social links read `"Open \(handle)"` with no network — identical when the coach uses the same handle on X and Instagram. Each list card's delete reads "Delete Email interaction". `"Open Instagram profile @\(handle)"` doubles the "@" when the stored handle already has one.
- user impact: VoiceOver users navigating by control cannot tell which coach or which network a button acts on, or that tapping a phone number starts a call.
- fix: Include the target: "Email \(coach.fullName)", "Call \(formattedPhone)", "Open \(handle) on Instagram", "Delete \(subject ?? type) interaction".

### [Medium] Async results, saves and validation errors are not announced; several auto-dismiss
- category: timing
- confidence: high
- where: `Features/Coaches/Views/CoachesListView.swift:78-83`; `Features/Interactions/Views/InteractionsListView.swift:51-56`; `Features/InboundDrafts/Views/InboundDraftsView.swift:15-20`; `Features/Coaches/Views/CoachDetailView.swift:76-78,357-372`; `Features/Coaches/Components/CoachEditForm.swift:29-34,42-47,66-71,78-83,93-98,106-111`; `Features/CommunicationTemplates/Views/TemplateEditorView.swift:20-22`
- what: The only announcement in the whole area is `AddCoachView.swift:217`. Success/error toasts disappear after 3–4s without an announcement (shared `ToastModifier`); the "Saving…/Saved" toolbar status is silent and clears after 3s; "Copy Link" flips its visible text to "Copied" for 2s but `.accessibilityLabel("Copy profile link")` hides the change; edit-form validation errors appear as extra rows with no focus move; a template save error renders at the top of the scroll view while focus is on Save at the bottom.
- user impact: VoiceOver users do not learn that a delete, save, copy or validation succeeded or failed, including "Failed to discard this draft".
- fix: Announce in `ToastModifier` and on status changes with `AccessibilityNotification.Announcement`, move focus to the first invalid field with `@AccessibilityFocusState`, and let the Copy Link label follow `linkCopied`.

### [Medium] Rows do not reflow and clip text at accessibility sizes
- category: dynamic-type
- confidence: medium
- where: `Features/Coaches/Components/CoachCardView.swift:32-41,88-108`; `Features/Coaches/Components/CoachInteractionsLogSection.swift:204-247,228-233`; `Features/Interactions/Components/InteractionCard.swift:53-86,89-93,98-117`; `Features/Interactions/Views/InteractionDetailView.swift:212-215`; `Features/Coaches/Components/CoachAnalyticsCard.swift:15`; fixed glyphs at `Features/Coaches/Components/CoachDetailHeader.swift:114,127`, `CoachDirectChannelsGrid.swift:51,53`, `CoachInteractionsLogSection.swift:208-210`
- what: Name + `Spacer` + role badge, and icon + type + direction badge + date, are single `HStack`s with no `ViewThatFits`/accessibility-size branch. In the coach log the subject is `.lineLimit(1)` and the expanded state never shows it in full. The interaction detail grid is always two columns with values limited to two lines (shared `DetailGridItem`). Several icons use `.font(.system(size:))` or fixed frames.
- user impact: At the largest sizes names wrap into narrow columns and long subjects or school names are cut off, with the coach-log subject unrecoverable on that screen.
- fix: Stack vertically when `dynamicTypeSize.isAccessibilitySize`, repeat the full subject in the expanded row, use one grid column at accessibility sizes, and size icons with `@ScaledMetric`.

### [Medium] Coach-log filter menus have no label or state for VoiceOver
- category: voiceover
- confidence: high
- where: `Features/Coaches/Components/CoachInteractionsLogSection.swift:123-141`
- what: `filterMenu` sets no accessibility label/value, so the button reads only its title — "Type" when inactive, then just "Email", "Outbound" or "Last 30 days" once a filter is chosen. The active state is shown only by the fill colour. (`CoachFilterBar.swift:39-41` does this correctly with label + value.)
- user impact: Once a filter is active a VoiceOver user hears a bare value with no indication which filter it is or that it is applied.
- fix: `.accessibilityLabel("Filter by type").accessibilityValue(viewModel.filterType?.displayName ?? "All types")` per menu.

### [Medium] Quick Communication message editor is unlabelled
- category: forms
- confidence: high
- where: `Features/Coaches/Views/QuickCommunicationView.swift:715-723`
- what: The visible `Text("Message")` is a separate sibling and the `TextEditor(text: $text)` has only an `accessibilityIdentifier`, no `accessibilityLabel`.
- user impact: VoiceOver announces an unnamed text view on the main compose step; Voice Control has no name to target.
- fix: Add `.accessibilityLabel("Message")` to the editor and hide the caption from VoiceOver, or wrap both in `LabeledContent`.

### [Medium] Discarding an inbound draft is immediate and irreversible
- category: forms
- confidence: medium
- where: `Features/InboundDrafts/Views/Components/InboundDraftCard.swift:51-57`; `Features/InboundDrafts/Views/InboundDraftsView.swift:69`; `Features/InboundDrafts/ViewModels/InboundDraftsViewModel.swift:65-79`
- what: `onDiscard: { Task { await viewModel.discard(draft) } }` deletes the forwarded email on a single tap with no confirmation or undo, and the card vanishes with no announcement. Every other delete in this area confirms first.
- user impact: An accidental activation (mis-tap, Voice Control mis-recognition, switch scanning) permanently loses a coach email, contrary to WCAG 3.3.4.
- fix: Add a `confirmationDialog` (as the interaction and coach deletes do) or an undo toast, and announce the removal.

### [Medium] Shared notes save only on focus loss, with no explicit way to finish editing
- category: voiceover
- confidence: low
- where: `Features/Coaches/Components/NotesSection.swift:25-40`
- what: The `TextEditor` saves in `.onChange(of: isFocused) { if !focused { await onBlur() } }`. There is no Done button, keyboard toolbar or Save control, so saving depends on dismissing the keyboard by scroll-drag or tapping elsewhere.
- user impact: VoiceOver and Switch Control users may have no reliable way to end editing and therefore to save notes.
- fix: Add a keyboard toolbar "Done" (`ToolbarItemGroup(placement: .keyboard)`) that clears focus, or an explicit Save button.

### [Low] Labels contain the control type or gesture, or state the wrong destination
- category: voiceover
- confidence: high
- where: `Features/Interactions/Views/AddInteractionView.swift:64,148,185,213,240,263,278,291,315`; `Features/Coaches/Components/CoachEditForm.swift:153`; `Features/Coaches/Components/NotesSection.swift:35`; `Features/Coaches/Views/CoachDetailView.swift:108`; `Features/Interactions/Views/InteractionDetailView.swift:78,227,248`; `Features/Interactions/Components/InteractionCard.swift:46,148`; `Features/CommunicationTemplates/Components/TemplateCardView.swift:53`
- what: "School picker", "Coach picker", "Subject field", "Toggle next contact date", "Shared Notes editor", "Coach actions menu" produce "picker, button"-style double announcements. Hints say "Double tap to delete…" / "Tap to view details", and two labels embed ", tap to view details". The Cancel button is labelled "Cancel and return to school details" although the form is also opened from coach detail, the interactions list and the drafts queue.
- user impact: Redundant or misleading speech; the Cancel label names the wrong place.
- fix: Drop the control-type words, move instructions to hints phrased as outcomes ("Opens details"), and label Cancel simply "Cancel".

### [Low] Placeholder dashes and a permanently empty "Event" tile add noise
- category: voiceover
- confidence: medium
- where: `Features/Interactions/Views/InteractionDetailView.swift:228-234,250-264`; `Features/Coaches/Components/CoachProfileMetaCard.swift:34`; `Features/Coaches/Components/CoachStatsGrid.swift:28,60`
- what: Missing values render as "—" and are included in the combined label ("Event: —", "Source —"); the Event tile is always empty ("not yet implemented").
- user impact: VoiceOver reads a dash or nothing instead of "none"; the Event tile is a dead stop.
- fix: Use "None"/"Not set" in the accessibility label and hide the Event tile until it has data.

### [Low] Raw user-ID fragments are used as names
- category: voiceover
- confidence: high
- where: `Features/Interactions/Components/InteractionFilterBar.swift:164,197,241`; `Features/Interactions/Components/InteractionActiveFilterChips.swift:60`
- what: `"\(athlete.role.capitalized) (\(athlete.userId.prefix(8)))"` is shown and spoken, e.g. "Athlete (a1b2c3d4)".
- user impact: VoiceOver spells out hex characters and Voice Control users cannot say the option's name.
- fix: Use the family member's display name.

### [Low] Progress indicators without a label
- category: voiceover
- confidence: medium
- where: `Features/Coaches/Views/QuickCommunicationView.swift:530`; `Features/InboundDrafts/Views/Components/InboundDraftCard.swift:64-66`; `Features/Coaches/Views/AddCoachView.swift:175-178`; `Features/Interactions/Views/AddInteractionView.swift:384-387`
- what: Bare `ProgressView()`; in the draft card it replaces the "Confirm" text entirely while a discard is pending, so the button loses its name.
- user impact: VoiceOver reads a generic "In progress" with no context.
- fix: `ProgressView().accessibilityLabel("Loading templates")`; keep the button's label constant and add `.accessibilityValue("In progress")`.

### [Low] Edit-coach form order and required-field cues
- category: forms
- confidence: high
- where: `Features/Coaches/Components/CoachEditForm.swift:23-40,59-76,132-153`
- what: The disabled `DatePicker("Next Contact")` precedes the toggle that enables it; first/last name are required (see the validation keys) but not marked visually or in the label; email and phone lack `textContentType`.
- user impact: Screen-reader users meet a dimmed control before the switch that explains it, and learn a field is required only after a failed save.
- fix: Put the toggle first, add ", required" to the name labels with a visible marker, and set `.textContentType(.emailAddress)` / `.telephoneNumber`.

### [Low] Toggle carries a button trait; footer labels drop text
- category: voiceover
- confidence: medium
- where: `Features/Interactions/Views/InteractionAddSchoolSheet.swift:151-154,201-205`
- what: `Toggle("Search college database", ...).accessibilityAddTraits(.isButton)` and footers whose `accessibilityLabel` is a shortened version of the visible sentence.
- user impact: Slightly confusing role announcement and spoken text that differs from what is shown.
- fix: Remove the trait and the footer label overrides.

### [Low] Filter value repeats the label; result changes are silent
- category: voiceover
- confidence: high
- where: `Features/Coaches/Components/CoachFilterBar.swift:65-73`; `Features/Coaches/Views/CoachesListView.swift:190-199`; `Features/Interactions/Views/InteractionsListView.swift:183-192`
- what: With no filter the last-contact menu reads "Filter by last contact, Last Contact" (value is `lastContactLabel`, not "Any time"); the result count changes after filtering or searching with no announcement.
- user impact: Minor redundancy, and no feedback that the list just changed.
- fix: Return "Any time" for the nil value and announce the new result count.

### [Low] Direction picker subtitle is unlikely to be visible
- category: forms
- confidence: low
- where: `Features/Interactions/Views/AddInteractionView.swift:228-241`
- what: A `.segmented` picker is given a two-line `VStack` label per segment ("Outbound" + "We initiated"); segmented controls render a single line, so the explanation probably exists only in the accessibility hint.
- user impact: Sighted users, including Voice Control users, may not see what Outbound/Inbound mean.
- fix: Put "We initiated / They initiated" in the section footer.

---

## Done well
- Icon-only toolbar buttons are labelled and sized: `CoachesListView.swift:45-65`, `InteractionsListView.swift:36-44` (`minWidth/minHeight: 44` + `contentShape`).
- `CommunicationButton.swift:37-41` and the `InteractionCard.swift:38-46` delete button meet 44pt with label and hint.
- `InteractionCard.swift:16-20` handles the nested-button row correctly (combined content + `.isButton` + composed label), keeping Delete as a sibling.
- Selected state is exposed with `.isSelected` on template options (`QuickCommunicationView.swift:592`), template tabs and filter pills (`CommunicationTemplatesView.swift:62,139`).
- `CoachFilterBar.swift:39-41,99-101` gives menus a label, hint and current value.
- Decorative icons are consistently `.accessibilityHidden(true)`; stat and analytics cards are combined with meaningful labels (`CoachAnalyticsCard.swift:47-49`, `AnalyticsCard.swift:36-37`, `CoachStatsGrid.swift:109`, `CoachInteractionsLogSection.swift:173-174`).
- Status is never colour-only: Overdue, Sent/Received, sentiment and role all carry text; unresolved template tokens are bold and keep their `{{token}}` text as well as colour, with a written notice (`QuickCommunicationView.swift:271-282`).
- Fonts are semantic text styles almost everywhere; `sizeCategory` branches enlarge icons and field heights (`CoachEditForm.swift:15-17`, `NotesSection.swift:11-13`, `InteractionCard.swift:10`).
- No `withAnimation`, `.animation` or `.transition` in the four feature folders; the shared toast already respects Reduce Motion.
- Add Coach announces school selection (`AddCoachView.swift:210-218`), uses `FormErrorSummary` (which announces) and explains a disabled submit in its hint (`:189-193`).
- Destructive coach, interaction and template deletes all confirm first.
- `CoachDetailHeader.swift:28` marks the coach name as a header; `InteractionDetailView.swift:139,188,210` mark subject/Content/Details as headers.

## Needs simulator verification
- Whether a `TextField` inside `.accessibilityElement(children: .combine)` (`FormFieldWrapper`, `QuickCommSpecificityField`) still reads as an editable text field with its value, and how the Tags buttons surface (custom actions vs lost).
- What VoiceOver actually focuses on a coach list card (`Button` label with `.contain` children) and whether double-tapping the name opens detail.
- Coach detail and Quick Communication at AX5 on a small iPhone: channel grid, stat cards, summary tiles, card header rows.
- Dark mode pass over coach detail (alert banners, overdue card, role badges, blue link text, warning/error captions).
- Whether VoiceOver/Switch users can end editing in the Shared Notes `TextEditor` so the blur-save fires.
- Whether the accessibility escape gesture still pops `AddCoachView` and `AddInteractionView`, which hide the system back button (`AddCoachView.swift:52`, `AddInteractionView.swift:56`).
- How the segmented Direction picker renders its two-line labels.
- Focus behaviour when coach detail reloads from realtime updates (`CoachDetailView.swift:233-247`) and after an inbound draft card is removed.
- Measured contrast for `.secondary` text on the tinted surfaces and for the Instagram gradient button.
