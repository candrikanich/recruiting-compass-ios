# Accessibility findings — Profile / Preferences / PublicProfile / Family / Settings

Scope read in full: every View/Component file in `Features/Preferences`, `Features/Profile`, `Features/PublicProfile`,
`Features/Family`, `Features/Settings` (plus the view-model lines that drive what is shown/announced, and the shared
pieces these views lean on: `SaveStatusView`, `Toast`/`ToastModifier`, `Banner`, `AsyncButton`, `LoginFormField`,
`KeyboardFieldNavigation`, `AppColors`). Static review only — nothing was built or run.

Counts: Blocker 0 · High 9 · Medium 12 · Low 10

Contrast ratios below are computed from the hex/system values in code against the stated background; they are
estimates, not measurements.

---

## High

### [High] Async results and errors are never announced, and success messages disappear after 2 s
- category: voiceover
- confidence: high
- where: zero `AccessibilityNotification` / `UIAccessibility.post` / `@AccessibilityFocusState` in all five folders. Instances:
  `Features/Profile/Views/ProfileView.swift:122-126` (photo error), `:171-176` (personal info result), `:239-244` (email error), `:303-315` (password mismatch + result), `:391-396` (deletion error);
  `Features/Profile/ViewModels/ProfileViewModel.swift:211-213`, `:261-263` (success shown for 2 s then cleared);
  `Features/Profile/Views/ProfileDataExportRow.swift:12-20, 36-41` (export button silently swaps to ShareLink; error);
  `Features/PublicProfile/Views/PublicTab.swift:54-60` (`saveError`, rendered far below the control that caused it), `:159-163` (`slugError`);
  `Features/Family/Views/InviteJoinView.swift:205-207, 328-330` (error banner inserted at top of a scroll view after tapping a button at the bottom);
  `Features/Family/Views/InviteAthleteView.swift:33-37`; `Features/Family/Views/ParentOnboardingWizardView.swift:21-27`; `Features/Family/Views/InviteJoinBirthdayConfirmView.swift:38-42`;
  `Features/Preferences/Views/HomeLocationView.swift:93-108` ("Coordinates Ready" appears after lookup);
  `Features/Preferences/Views/NotificationPreferencesView.swift:83-87` (`pushSetupError`);
  autosave status `SaveStatusView` in the nav bar: `Features/Preferences/Views/PlayerDetailsView.swift:37`, `DashboardCustomizationView.swift:170`, `HomeLocationView.swift:145`, `NotificationPreferencesView.swift:144`, `SchoolPreferencesView.swift:109`.
- what: results are rendered as inline `Text`/`Label` only, e.g. `personalInfoMessage = .success("Saved!"); try? await Task.sleep(for: .seconds(2)); personalInfoMessage = nil`. Nothing posts an announcement or moves focus.
- user impact: a VoiceOver user who changes their password, email or name, or triggers an autosave, gets no confirmation and no error unless they go hunting for it — and the success text is gone after 2 seconds.
- fix: post `AccessibilityNotification.Announcement(text).post()` wherever these messages are set (the app already has `Core/Protocols/AccessibilityAnnouncing.swift` for this — inject it into the view models); for errors also move focus with `@AccessibilityFocusState` to the error text. Keep success text visible until the next edit instead of 2 s. In `SaveStatusView`, announce on `.saved`/failure.

### [High] `.accessibilityElement(children: .combine)` + label override swallows the Remove and Copy buttons
- category: voiceover
- confidence: medium (exact merged behaviour needs a VoiceOver check; it is wrong either way)
- where: `Features/Family/Components/FamilyMemberCard.swift:59-73`; `Features/Family/Components/ForwardCoachEmailsCard.swift:10-46`
- what: the member card wraps the trash button (`.accessibilityLabel(removeAccessibilityLabel)`) and then applies `.accessibilityElement(children: .combine).accessibilityLabel(cardAccessibilityLabel)` to the whole card; the forwarding card does the same around its "Copy" button. The child's "Remove <name>" / "Copy forwarding address to clipboard" label is discarded; the element reads "Jane Doe, parent, joined 9/1/26" and either exposes no remove action or makes double-tap silently start a removal. The forwarding card's label override also drops the explanatory paragraph and the family name.
- user impact: a VoiceOver or Voice Control user cannot find (or cannot tell they are triggering) "Remove family member" and "Copy forwarding address".
- fix: combine only the text (`VStack` of name/role/date) and leave the button as a sibling element; or keep `.combine` and add `.accessibilityAction(named: "Remove \(displayName)") { onRemove() }` / `.accessibilityAction(named: "Copy address") { onCopy() }`. Don't override the label on a container that holds a control.

### [High] Public-profile section reorder buttons share one label and are tiny
- category: voiceover
- confidence: medium (label propagation to both children needs a VoiceOver check)
- where: `Features/PublicProfile/Views/PublicTab.swift:343-362`
- what: `VStack(spacing: 2) { Button { … } label: { Image(systemName: "chevron.up") }; Button { … } label: { Image(systemName: "chevron.down") } }.font(.caption).accessibilityLabel("Reorder \(section.key.label)")` — the label sits on the non-element `VStack`, so both icon-only buttons get the same name ("Reorder Athletic Metrics") with no direction. Each target is a caption-sized chevron (~12×8 pt) stacked 2 pt apart.
- user impact: VoiceOver/Voice Control users can't tell "move up" from "move down"; motor-impaired users can't reliably hit either.
- fix: label each button (`"Move \(label) up"` / `"…down"`), give each `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())`, lay them out side by side, and announce the new position. Better: expose one element with `.accessibilityAdjustableAction` or `accessibilityAction(named:)` "Move up"/"Move down" (same as `AthleticsTab.positionPriorityRow`, which already labels its buttons correctly).

### [High] Bio and "What I'm Looking For" editors have no accessibility label
- category: voiceover
- confidence: high
- where: `Features/PublicProfile/Views/PublicTab.swift:213-221`, `:233-241`
- what: `Text("Bio")` followed by a bare `TextEditor(text: $vm.bio)`; same for `lookingFor`. `TextEditor` takes no title, and neither has `.accessibilityLabel`.
- user impact: VoiceOver reads two anonymous "text field" elements on the screen that controls what college coaches see; Voice Control has no name to target.
- fix: `.accessibilityLabel(String(localized: "Bio"))` / `"What I'm looking for"`, and `.accessibilityValue`/hint with the remaining character count (see Low "character counters").

### [High] Text fields are named by their placeholder, not their field name
- category: forms
- confidence: high
- where:
  `Features/Preferences/Views/Tabs/AcademicsSocialTab.swift:98, 120` — GPA, SAT Score, ACT Score fields are `TextField("–", value: …)`;
  `Features/Preferences/Views/Tabs/BasicsTab.swift:154` (phone → "(555) 123-4567"), `:171, 173, 175` (Twitter / Instagram / TikTok all → "@username"), `:177` (Facebook → "https://...");
  `Features/Preferences/Views/Tabs/AthleticsTab.swift:243` (`service.placeholder`), `:275`;
  `Features/PublicProfile/Views/PublicTab.swift:153` (Custom URL → "your-name");
  `Features/Preferences/Components/CoreCoursesEditor.swift:58` ("e.g., AP Chemistry");
  ambiguous repeats: `Features/Preferences/Views/Tabs/HistoryTab.swift:241, 243` ("Team"/"Coach" ×4 grades), `:135, 137, 156` ("Organization"/"Head Coach"/"Season Year" per travel team).
- what: rows are `HStack { Text(label); Spacer(); TextField(placeholder, …) }` with no grouping, so the field's accessible name is the placeholder: three fields called "dash", three called "@username", eight called "Team"/"Coach".
- user impact: with VoiceOver (especially touch exploration or the rotor) and Voice Control the user cannot tell which score, handle or grade they are editing.
- fix: add `.accessibilityLabel(label)` to each `TextField` (for History: `"\(gradeLabel) team"`, `"Team \(n) organization"`), and hide the sibling `Text(label)` from accessibility or wrap the row in `.accessibilityElement(children: .combine)` as project CLAUDE.md requires for form fields.

### [High] Parent onboarding: under-13 error is colour-only and the disabled "Get Started" gives no reason
- category: color
- confidence: high
- where: `Features/Family/Views/ParentOnboardingWizardView.swift:88-94`, `:61`, `:144-163`; `Features/Family/ViewModels/ParentOnboardingWizardViewModel.swift:71-80`
- what: the only under-age feedback is `.foregroundStyle(hasConfirmedDateOfBirth && isPlayerUnderAge ? Color.red : Color.secondary)` on unchanged helper text. "Get Started" is disabled until first name is non-empty AND the date picker has been changed AND the player is 13+, but none of that is stated: no required markers, no hint, and the intro copy says "Name, sport, and graduation year are optional" while validation requires the name.
- user impact: VoiceOver, colour-blind and low-vision users hit a dimmed button with no explanation on the first screen after sign-up.
- fix: show an explicit error row (icon + "Player must be 13 or older") and announce it; mark first name and date of birth as required in the visible label and `accessibilityLabel`; add `.accessibilityHint` on the disabled button listing what is missing; correct the intro copy.

### [High] Styled buttons whose tappable area is only the text, not the coloured bar
- category: hit-target
- confidence: high
- where: `Features/Family/Views/FamilyManagementParentView.swift:45-59` (Join Family), `:96-110` (Send); `Features/Family/Views/FamilyManagementPlayerView.swift:141-155` (Send); `Features/Family/Views/InviteAthleteView.swift:39-55` (Send Invite)
- what: sizing and background are applied to the `Button`, not its label: `Button { … } label: { Text("Join Family") }.frame(maxWidth: .infinity).padding(.vertical, …).background(Color.blue)…`. Only the label (the word, ~20 pt tall) is hit-testable; the rest of the full-width bar is dead.
- user impact: users with motor or low-vision needs tap the visible button and nothing happens; the real target is well under 44×44 pt.
- fix: move `.frame(maxWidth: .infinity, minHeight: 44)`, padding and background inside the label closure (as `ParentOnboardingWizardView.swift:146-156` does), or use `AsyncButton`, which already handles this.

### [High] Completeness percentage is yellow/green text on a white card
- category: color
- confidence: medium
- where: `Features/Preferences/Components/PlayerCompletenessCard.swift:10-16, 25-28`
- what: `Text("\(percentage)%").foregroundStyle(progressColor)` where `progressColor` is `.yellow` (40–74 %), `.green` (75 %+) or `.red`, on `secondarySystemGroupedBackground`. In light mode that is roughly 1.5:1 (yellow), 2.2:1 (green), 3.6:1 (red) against a 4.5:1 requirement.
- user impact: the headline number on the Player Profile editor is unreadable for low-vision users for most of its range (VoiceOver is fine — the card has a good label).
- fix: render the number in `.primary` and keep colour on the bar only, or use adaptive AA-safe tones (`Color.amberGold`, `Color.Brand.emerald700`, `Color.Brand.red600`).

### [High] Birthday-confirm sheet may trap users at large text sizes
- category: dynamic-type
- confidence: low (layout not verifiable statically — if confirmed, this is a Blocker)
- where: `Features/Family/Views/InviteJoinBirthdayConfirmView.swift:10-58`; presented at `Features/Family/Views/InviteJoinView.swift:34-37`
- what: a wheel `DatePicker`, heading, explanatory text, optional error and the Confirm button sit in a plain `VStack` (no `ScrollView`) inside `.presentationDetents([.medium])` with `.interactiveDismissDisabled()`.
- user impact: at accessibility text sizes the Confirm button is likely pushed off the visible half-sheet with no way to scroll to it or dismiss, stranding a new player in the invite flow.
- fix: wrap the content in a `ScrollView`, add `.large` to the detents (or switch detent on `dynamicTypeSize.isAccessibilitySize`), and use `.datePickerStyle(.compact)` at accessibility sizes.

---

## Medium

### [Medium] Section and card titles are not headings
- category: voiceover
- confidence: high
- where: `cardSection` helper in `Features/Preferences/Views/Tabs/BasicsTab.swift:400-405`, `AthleticsTab.swift:470-475`, `AcademicsSocialTab.swift:142-147`, `HistoryTab.swift:249-254`; grade sub-headings `HistoryTab.swift:236-240`;
  `Features/PublicProfile/Views/PublicTab.swift:486` (`boxedCard` title), `:415` ("What coaches see"), `:469`;
  `Features/Family/Views/FamilyManagementParentView.swift:24, 74, 128, 184`; `FamilyManagementPlayerView.swift:51, 119, 173, 229`; `Features/Family/Components/ForwardCoachEmailsCard.swift:18`;
  `Features/Family/Views/InviteAthleteView.swift:15`; `InviteJoinView.swift:106, 137, 193`; `InviteJoinBirthdayConfirmView.swift:16`; `ParentOnboardingWizardView.swift:57`.
- what: titles are plain `Text` with no `.accessibilityAddTraits(.isHeader)` (only `PublicProfileSections.swift:289` has it).
- user impact: the Player Profile tabs are long forms; VoiceOver users cannot jump between sections with the Headings rotor.
- fix: add `.accessibilityAddTraits(.isHeader)` in the four `cardSection` helpers and `boxedCard`, and on the listed headline `Text`s.

### [Medium] Accessibility labels that don't contain the visible text (Voice Control)
- category: voice-control
- confidence: medium
- where (visible → label):
  `Features/Preferences/Views/Tabs/BasicsTab.swift:87-89` "Choose Photo" → "Choose profile photo";
  `Features/Preferences/Views/HomeLocationView.swift:22, 30` "Use My Location" → "Use current location"; `:82, 90` "Lookup from Address" → "Lookup coordinates from address";
  `Features/Preferences/Views/NotificationPreferencesView.swift:70, 74` "High-Priority Only" → "Email high-priority notifications only"; `:29, 36` "Days between reminders: N" → "Days between follow-up reminders";
  `Features/Profile/Views/ProfileView.swift:107, 111` "Upload Photo" → "Upload profile photo"; `:458, 465` "Yes, delete my account" → "Confirm account deletion";
  `Features/Profile/Views/ProfileDataExportRow.swift:14, 19` "Share or Save Export" → "Share or save your data export";
  `Features/PublicProfile/Views/PublicTab.swift:438, 446` "Download as PDF" → "Download profile as PDF";
  `Features/Family/Views/InviteAthleteView.swift:23, 29` "Player's email address" → "Player email for invite";
  `Features/Family/Views/ParentOnboardingWizardView.swift:67, 71` "Player's first name" → "Athlete first name"; `:96, 105` "Primary sport" → "Athlete sport"; `:111, 120`; `:123, 135`.
- what: the label rewrites the visible words, so "Tap Upload Photo" doesn't match (WCAG 2.5.3 Label in Name). Wizard labels also say "Athlete" where the screen says "Player".
- user impact: Voice Control users must fall back to "Show numbers" for these controls.
- fix: start the label with the visible text, or keep the descriptive label and add `.accessibilityInputLabels(["Upload Photo", "Upload"])`.

### [Medium] Small hit targets (under 44×44 pt)
- category: hit-target
- confidence: medium (sizes inferred from font + padding)
- where:
  `Features/Preferences/Views/Tabs/AthleticsTab.swift:357-373` (move up/down chevrons, footnote-sized, plain style), `:298-307`, `:314-323` (caption "Get your profile"/"View profile" links);
  `Features/Preferences/Views/Tabs/HistoryTab.swift:120-128` (trash);
  `Features/Preferences/Components/CoreCoursesEditor.swift:38-44` (caption2 xmark);
  `Features/Preferences/Components/PositionChipsView.swift:55-64` (chips ≈28 pt tall);
  `Features/Preferences/Views/PlayerDetailsView.swift:73-87` (tab pills ≈36 pt tall);
  `Features/Preferences/Components/PreferenceRow.swift:36-42` (dealbreaker icon);
  `Features/Preferences/Views/DashboardCustomizationView.swift:81-84`, `:112-115` (caption "Select All" in section headers);
  `Features/PublicProfile/Views/PublicTab.swift:263-268`, `:300-305` (remove xmarks), `:368-373` (eye toggle);
  `Features/PublicProfile/Components/ShareLinkRow.swift:15-18`; `Features/PublicProfile/Components/HeaderColorPicker.swift:10-17` (32 pt swatches);
  `Features/PublicProfile/Views/PublicProfileCard.swift:251-258`, `:300-305` (social links);
  `Features/Settings/Views/SettingsView.swift:65-77`, `:196-210` (caption "Copy");
  `Features/Family/Views/FamilyManagementParentView.swift:146-160`, `FamilyManagementPlayerView.swift:191-205` (caption Resend/Revoke side by side);
  `Features/Family/Views/InviteJoinView.swift:228-233` (plain-text mode switch).
- what: icon/caption-sized tappables with no min frame or `contentShape`, e.g. `Button { viewModel.movePosition(index, .up) } label: { Image(systemName: "chevron.up") }.buttonStyle(.plain)`.
- user impact: hard to hit for motor-impaired users, and adjacent destructive/non-destructive pairs (Resend/Revoke, up/down) invite mis-taps.
- fix: `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` on each label (the pattern already used in `FamilyMemberCard.swift:63-64` and `PublicTab.swift:138`).

### [Medium] Header colour swatches are tap-gesture shapes, not buttons
- category: voiceover
- confidence: medium
- where: `Features/PublicProfile/Components/HeaderColorPicker.swift:10-19`
- what: `Circle()….onTapGesture { selection = color }.accessibilityLabel(Text(color.label)).accessibilityAddTraits(selection == color ? [.isSelected] : [])` — no `.isButton` trait. Selection is otherwise shown only by a ring.
- user impact: VoiceOver announces "Navy" with no hint that it is actionable; Voice Control / Switch Control may not offer it as a target.
- fix: make each swatch a `Button` (or add `.accessibilityAddTraits(.isButton)`), 44 pt frame, and group with `.accessibilityElement(children: .contain).accessibilityLabel("Hero background colour")`.

### [Medium] Fixed-width frames around text inputs and pickers
- category: dynamic-type
- confidence: medium
- where: `Features/Preferences/Views/Tabs/AcademicsSocialTab.swift:109, 131` (`.frame(width: 80)` on GPA/SAT/ACT); `Features/PublicProfile/Views/PublicTab.swift:315` (award Year, 80); `Features/Preferences/Views/HomeLocationView.swift:53` (State, 60); wheel pickers `Features/Preferences/Views/Tabs/BasicsTab.swift:340-342` (100×80, clipped), `AthleticsTab.swift:142-144, 157-159` (80×80, clipped); icon frames `Features/Settings/Views/SettingsView.swift:356-358`, `Features/Profile/Views/ProfileView.swift:346-348` (36×36 around a `.title3` symbol), `Features/Preferences/Components/PreferenceRow.swift:11`, `TemplateCard.swift:15`.
- what: e.g. `TextField("–", value: …).frame(width: 80)` — at accessibility sizes a four-digit SAT score no longer fits and is clipped.
- user impact: Larger Text users can't see the value they typed.
- fix: replace with `.frame(minWidth: 80)` / `@ScaledMetric var fieldWidth: CGFloat = 80`; switch wheel pickers to `.menu` when `dynamicTypeSize.isAccessibilitySize`.

### [Medium] Rows and grids that cannot reflow at accessibility text sizes
- category: dynamic-type
- confidence: medium
- where:
  label + trailing field rows: `Features/Preferences/Views/Tabs/BasicsTab.swift:188-207, 218-233`, `AthleticsTab.swift:240-258, 409-425`, `AcademicsSocialTab.swift:71-89`, `HistoryTab.swift:152-172, 183-200, 208-224`;
  three equal-width choice buttons: `BasicsTab.swift:294-314`, `AthleticsTab.swift:441-460`;
  `Features/PublicProfile/Views/PublicTab.swift:86-98` (title + status pill + toggle in one row), `:309-323` (title + year + Add);
  two-column and three-column cards: `Features/PublicProfile/Views/PublicProfileCard.swift:85-89`, `Features/PublicProfile/Components/PublicProfileSections.swift:17-20`, `:241-252`, `:300-309`;
  `Features/Preferences/Views/NotificationPreferencesView.swift:89-102`;
  `Features/Family/Views/FamilyManagementParentView.swift:137-161`, `FamilyManagementPlayerView.swift:182-206`;
  `Features/Settings/Views/SettingsView.swift:364-384` (title + badge);
  truncation: `Features/Preferences/Views/ToggleCard.swift:26` (`lineLimit(2)` in a half-width card), `SettingsView.swift:193-194`, `Features/Family/Components/ForwardCoachEmailsCard.swift:30-31`, `Features/PublicProfile/Components/ShareLinkRow.swift:12-13` (`lineLimit(1)` + middle truncation on the address/URL the user is meant to share).
- what: no `ViewThatFits`, `dynamicTypeSize` branch or `AnyLayout` anywhere in the area; everything stays horizontal.
- user impact: at AX sizes labels wrap a few characters per line, typed values are squeezed to a sliver, and the forwarding address / profile URL can never be read in full.
- fix: `let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())` in the row helpers; single column for the profile-card grids at accessibility sizes; drop `lineLimit(1)` on addresses (or add `.textSelection(.enabled)` and let them wrap).

### [Medium] Status pills and semantic colours below 4.5:1
- category: color
- confidence: medium
- where:
  `Features/PublicProfile/Views/PublicTab.swift:120-121` ("Your profile is live & public": `.green` on green 15 %, ≈2:1; "Not published": `Color.Text.muted` on `Surface.muted`, ≈3:1);
  `Features/Family/Components/FamilyMemberCard.swift:42-43`, `ParentFamilyCard.swift:23-24` (`.green` on green 20 %);
  `Features/Profile/Views/ProfileView.swift:492-494` (deletion date in `.orange` on orange 10 %, ≈2.2:1), `:174`, `:313` (`Color.primaryGreen` success text, ≈3.8:1 on white), `:223` (`.blue`, ≈4:1);
  `Features/Settings/Models/SettingsBadgeStatus.swift:22-34` (Complete ≈4.2:1, Incomplete ≈3.8:1);
  `Features/Preferences/Components/PreferenceRow.swift:26-33` ("DEALBREAKER" white on `Color.red`, ≈3.6:1);
  system-red caption errors: `PublicTab.swift:57, 162`, `Features/Family/Views/InviteAthleteView.swift:36`, `ParentOnboardingWizardView.swift:24, 92`, `InviteJoinBirthdayConfirmView.swift:41` (≈3.6:1);
  white on default accent blue (asset `AccentColor` has no custom value → system blue, ≈4:1): `Features/Preferences/Views/PlayerDetailsView.swift:78-84`, `BasicsTab.swift:305-306`, `AthleticsTab.swift:385, 451-452`, `Features/Preferences/Components/PositionChipsView.swift:61-62`, `Features/PublicProfile/Views/PublicProfileCard.swift:163-164`.
- what: system `.green`/`.orange`/`.red`/`.blue` used as small text colours on white or on their own tint.
- user impact: low-vision users can't read publish status, account-deletion date, role pills or error text.
- fix: use the darker adaptive tokens already in `AppColors` (`successBannerText`, `warningBannerTitle`, `Brand.red700`, `Brand.emerald700/800`) for text; keep the bright hue for the fill/icon only.

### [Medium] Muted / secondary / tertiary text below 4.5:1 in light mode
- category: color
- confidence: medium
- where: `Color.Text.muted` (#7A8BA0, ≈3.3:1 on `Surface.card`, ≈3:1 on `Surface.muted`): `Features/PublicProfile/Views/PublicTab.swift:182, 185, 396`, `Features/PublicProfile/Components/PublicProfileSections.swift:58, 74, 180, 191, 250, 303, 315`, `Features/PublicProfile/Views/PublicProfileCard.swift:295, 303, 312`, `Features/PublicProfile/Components/ProfileQRCodeView.swift:21`;
  `.tertiary` text: `Features/Preferences/Views/Tabs/AthleticsTab.swift:355, 391`, `Features/Preferences/Components/PositionChipsView.swift:21`;
  user-entered values styled `.secondary`: every `TextField` in `BasicsTab.swift:199, 229`, `AthleticsTab.swift:179, 251, 283, 420`, `AcademicsSocialTab.swift:82, 107, 129`, `HistoryTab.swift:168, 195, 219`.
- what: field labels in the coach-facing preview ("High School", "GPA", metric names), the "Select a sport above…" instruction, and the user's own typed values are rendered in low-contrast greys.
- user impact: low-vision users struggle to read the labels in the profile preview and the data they just entered.
- fix: darken `Color.Text.muted` light value to ≥4.5:1 (e.g. slate-600 `#475569`); use `.primary` for entered values and `.secondary` (not `.tertiary`) for instructions.

### [Medium] Non-adaptive `errorRed` text in dark mode
- category: dark-mode
- confidence: medium
- where: `Core/Theme/AppColors.swift:78` (`errorRed = Brand.red600`, no dark variant) used as text in `Features/Profile/Views/ProfileView.swift:125, 174, 242, 306, 313, 394, 418, 437, 479`, `Features/Profile/Views/ProfileDataExportRow.swift:39`, `Features/Preferences/Views/NotificationPreferencesView.swift:86`.
- what: #DC2626 on the dark list-row background (#1C1C1E) is ≈3.5:1; the neighbouring text tokens in the same file are adaptive, this one is not.
- user impact: error messages and the delete-account warning are hard to read in Dark Mode.
- fix: `static let errorRed = Color(light: Brand.red600, dark: Color(hex: "f87171"))`.

### [Medium] Placeholder-only fields with no persistent visible label
- category: forms
- confidence: high
- where: `Features/Preferences/Views/HomeLocationView.swift:33, 42, 50, 61`; `Features/Profile/Views/ProfileView.swift:164, 228, 235, 291, 295, 299` (incl. "New Password (min 8 characters)" — the rule vanishes once typing starts); `Features/Preferences/Components/AddPreferenceSheet.swift:36`; `Features/PublicProfile/Views/PublicTab.swift:275, 310, 312`; `Features/Family/Views/FamilyManagementParentView.swift:34, 89`; `FamilyManagementPlayerView.swift:134`.
- what: `TextField("City", text: …)` inside a `Form`/card with no adjacent label; VoiceOver labels are present, but the visible name disappears once the field has content.
- user impact: low-vision and cognitive-disability users lose track of which field is which when reviewing a filled form (e.g. City vs. Street, the three password fields).
- fix: use `LabeledContent("City") { TextField("", text: …) }` or the label+field row pattern used in the Player Profile tabs; keep the password rule as a persistent footer.

### [Medium] Copy confirmations and toasts are silent and short-lived
- category: timing
- confidence: high
- where: `Features/Family/Views/FamilyManagementView.swift:26-31` (3 s toast for copy/invite/resend/revoke/regenerate), `InviteAthleteView.swift:127-138`, `InviteJoinView.swift:38-61` (2–3 s, including the "birthday save failed" error toast); `Features/Settings/Views/SettingsView.swift:65-78, 196-211` ("Copied!" for 2 s, label changes while focused); no feedback at all: `Features/Family/Views/InviteAthleteView.swift:87-94` (Copy family code), `Features/PublicProfile/Views/PublicTab.swift:130-132` + `Features/PublicProfile/Components/ShareLinkRow.swift:15-18` (Copy profile link).
- what: `Shared/Components/Toast.swift` / `ToastModifier.swift` post no announcement and auto-dismiss after `duration`; two copy buttons give no confirmation of any kind.
- user impact: VoiceOver users never learn that an invite was sent or revoked, or that a code was copied; slow readers lose the toast before finishing it.
- fix: post `AccessibilityNotification.Announcement(message)` when a toast appears (one fix in `ToastModifier`), lengthen or pause dismissal while VoiceOver is running, and add a toast/announcement to the two silent copy actions.

### [Medium] Reordering gives no feedback about the new position
- category: voiceover
- confidence: high
- where: `Features/Preferences/Views/Tabs/AthleticsTab.swift:349-379` (position priority — decides which position coaches see first); `Features/PublicProfile/Views/PublicTab.swift:341-379`
- what: after `viewModel.movePosition(index, .up)` the rows re-render; nothing is announced, and focus stays on a button that now belongs to a different row (the `ForEach` identity is the position string, the button sits at the old index).
- user impact: a VoiceOver user can't tell whether the move happened or which position is now PRIMARY without re-reading the list.
- fix: announce `"\(pos) moved to position \(n)"`; expose the row as one element with `accessibilityValue("Priority \(index + 1) of \(count)")` and "Move up"/"Move down" custom actions.

---

## Low

### [Low] Duplicated or awkward state wording in labels
- category: voiceover
- confidence: high
- where: `Features/Preferences/Components/PositionChipsView.swift:66-67` (label "Pitcher, selected" plus `.isSelected` → "selected, Pitcher, selected"); `Features/Preferences/Views/ToggleCard.swift:60-66` (label "Coaches enabled/disabled" + `.isSelected`, hint "Tap to toggle"); `Features/Family/Views/FamilyManagementParentView.swift:60` ("Join family button" → "…button, button"); `Features/Preferences/Views/HomeLocationView.swift:91` (hint "Tap to geocode address").
- what: state is baked into the label as well as the trait; control type and gesture named in label/hint.
- user impact: verbose, slightly confusing VoiceOver output ("disabled" reads like the control is unavailable).
- fix: label = name only; state via `.isSelected` or `.accessibilityValue`/`.isToggle`; drop "button"/"Tap to".

### [Low] Field name read twice / label and control are separate stops
- category: voiceover
- confidence: high
- where: all `HStack { Text(label); Spacer(); TextField(label, …) }` rows in the four Player Profile tabs; `Features/Preferences/Views/DashboardCustomizationView.swift:95-105` (`Text(id.label)` + `Toggle` labelled `id.label`); `BasicsTab.swift:326-343`, `:350-367` (Text + Picker with the same title).
- what: VoiceOver stops on "High School" then on "High School, text field".
- user impact: doubles the swipe count through already long forms.
- fix: `.accessibilityHidden(true)` on the visual label or `.accessibilityElement(children: .combine)` on the row; for the widget row use `Toggle(isOn:) { Label(id.label, systemImage: id.icon) }`.

### [Low] Coach-preview card is read as many fragments
- category: voiceover
- confidence: high
- where: `Features/PublicProfile/Components/PublicProfileSections.swift:53-82` (metric label / "Verified" / value / unit as four elements; `metric.label.uppercased()`), `:299-310` (detail rows), `:239-260`; `Features/PublicProfile/Views/PublicProfileCard.swift:249` ("·" separators); `:325-329` (🏅 emoji prefix in the combined chip label).
- what: none of the rows are grouped.
- user impact: tedious preview; label and value can be dissociated.
- fix: `.accessibilityElement(children: .combine)` on `metricCard`, `detailRow`, `teamHistoryRow`; use `.textCase(.uppercase)` instead of `.uppercased()`; hide separators.

### [Low] Profile photos and decorative symbols not labelled / not hidden
- category: voiceover
- confidence: medium
- where: `Features/Preferences/Views/Tabs/BasicsTab.swift:109-133` (photo and `person.crop.circle.fill` placeholder); `Features/Profile/Views/ProfileView.swift:96-98, 137-153`; `Features/Preferences/Components/PreferenceRow.swift:9-11` (category icon inside a `.contain` row); `Features/PublicProfile/Views/PublicTab.swift:87`.
- what: images with neither a label nor `.accessibilityHidden(true)`.
- user impact: VoiceOver lands on "image" or the raw symbol name.
- fix: label the photo ("Profile photo" / "No profile photo"), hide decorative symbols.

### [Low] Character limits and counters are silent
- category: forms
- confidence: high
- where: `Features/PublicProfile/Views/PublicTab.swift:216-224, 236-244` (input silently truncated with `prefix(limit)`; counter "12/300"), `:282-286` (Add disabled at 12 values, "3/12"); `Features/Preferences/Components/CoreCoursesEditor.swift:12-18, 56-69` (duplicates and over-length input rejected with no message).
- what: counters are bare "n/m" text; rejections do nothing visible or audible.
- user impact: VoiceOver users hear "twelve slash three hundred"; anyone hitting a limit gets no explanation.
- fix: `.accessibilityLabel("\(count) of \(limit) characters used")`; announce when the limit is reached or an entry is rejected.

### [Low] Busy state not reflected in button labels
- category: voiceover
- confidence: high
- where: `Features/Family/Views/FamilyManagementParentView.swift:45-60, 96-111`; `FamilyManagementPlayerView.swift:141-156`; `InviteAthleteView.swift:39-56`; `ParentOnboardingWizardView.swift:144-163`; `Features/Profile/Views/ProfileDataExportRow.swift:21-33` (visible "Preparing Export…", label stays "Export my data"); `Features/Family/Views/InviteJoinView.swift:470-484`.
- what: the label is replaced by a `ProgressView` but the static `accessibilityLabel` is unchanged.
- user impact: VoiceOver users hear the same dimmed button with no "in progress" cue.
- fix: switch the label while loading (as `ProfileView.swift:191, 260, 330` and `AsyncButton` already do).

### [Low] Segmented choice rows: no group semantics, undisclosed deselect
- category: voiceover
- confidence: medium
- where: `Features/Preferences/Views/Tabs/BasicsTab.swift:285-322` (tapping the selected option clears it), `AthleticsTab.swift:432-464`; tab bar `Features/Preferences/Views/PlayerDetailsView.swift:68-93` (no "tab, 2 of 5").
- what: selection is exposed via `.isSelected` (good) but each option repeats the full group name ("Campus Size Preference: Small (<5K)") and the clear-on-retap behaviour is undiscoverable.
- user impact: verbose; users can't tell the preference is optional/clearable.
- fix: group with `.accessibilityElement(children: .contain).accessibilityLabel(label)`, label options with their own text, add hint "Double-tap again to clear"; add `.accessibilityAddTraits(.isTabBar)` to the tab container.

### [Low] Fixed font sizes
- category: dynamic-type
- confidence: high
- where: `Features/PublicProfile/Views/PublicProfileCard.swift:209` (`.font(.system(size: 44, weight: .semibold))` initial inside a fixed 112 pt avatar); `Features/Family/Views/InviteJoinView.swift:102, 133` (`.font(.system(size: 48))` on hidden decorative icons).
- what: three of the app's 37 fixed-size fonts; all decorative.
- user impact: none functionally; violates the project's "never `.system(size:)`" rule.
- fix: `.font(.largeTitle)` / `@ScaledMetric`.

### [Low] Family code read as a word in Settings
- category: voiceover
- confidence: medium
- where: `Features/Settings/Views/SettingsView.swift:57-62`
- what: `Text(code)` with no label, while the Family screens use `FamilyUtilities.formatCodeForVoiceOver(code)` (`FamilyManagementPlayerView.swift:64`, `ParentFamilyCard.swift:46`, `InviteAthleteView.swift:86`).
- user impact: VoiceOver may pronounce "FAM-7K2Q9X" as a garbled word.
- fix: `.accessibilityLabel("Family code \(FamilyUtilities.formatCodeForVoiceOver(code))")` or `.speechSpellsOutCharacters()`.

### [Low] Stepper with a 1…5000 range
- category: voiceover
- confidence: high
- where: `Features/Preferences/Components/AddPreferenceSheet.swift:32`
- what: `Stepper("Value: \(intValue)", value: $intValue, in: 1...5000)` in steps of 1, starting at 500, for "Max Distance (miles)".
- user impact: reaching 300 miles takes 200 activations (VoiceOver swipes, Switch Control selections or Voice Control commands).
- fix: numeric `TextField` with `.keyboardType(.numberPad)` or `step: 25`.

---

## Done well

- Reduced Motion: the only custom animation in the area is gated (`PlayerCompletenessCard.swift:6, 45`); there are no `withAnimation`, transitions, carousels or shimmer in these five folders. (`Shared/Components/SaveStatusView.swift:8` has an ungated 0.2 s fade — trivial.)
- `PlayerCompletenessCard.swift:52-53` collapses the bar into one element, "Profile N% complete".
- Selected state is exposed with `.isSelected` on the Player Profile tab bar (`PlayerDetailsView.swift:88-89`), choice rows, position chips and colour swatches.
- Icon-only buttons almost all have labels (`AthleticsTab.swift:364, 373`, `HistoryTab.swift:127`, `CoreCoursesEditor.swift:44`, `PublicTab.swift:269, 306, 374`, keyboard Previous/Next in `KeyboardFieldNavigation.swift:26, 36`).
- Family codes are spelled out for VoiceOver via `FamilyUtilities.formatCodeForVoiceOver`.
- `FamilyMemberCard.swift:63-64`, `PublicTab.swift:138, 442`, `ForwardCoachEmailsCard.swift:55` and `InviteJoinView.swift:480` set explicit 44 pt targets — reuse this pattern.
- `SettingsBadgeStatus` pairs colour with an icon and text ("Complete"/"Incomplete") and the row label includes the status (`SettingsView.swift:394-397`).
- Dark mode: the area uses system and adaptive `Surface`/`Text` tokens almost everywhere; the white invite/onboarding cards correctly force `.colorScheme(.light)` (`InviteJoinView.swift:15-17`, `InviteJoinBirthdayConfirmView.swift:54-56`, `ParentOnboardingWizardView.swift:30-32`); the PDF renderer forces light (`PublicProfilePDFRenderer.swift:30-31`).
- Semantic fonts throughout (3 exceptions listed above); `textContentType`/keyboard types are set on address, email and password fields; next/done focus chaining plus the keyboard toolbar cover number pads.
- Reorder and delete in `SchoolPreferencesView` and `DashboardCustomizationView` use native `List` `.onMove`/`.onDelete` with an `EditButton`, which VoiceOver handles natively.
- Destructive actions go through system alerts/confirmation dialogs, and load failures use `.alert`, which VoiceOver announces.
- Non-interactive "Contact Player / Express Interest" mock buttons in the preview are hidden from accessibility (`PublicProfileCard.swift:284`).

## Needs simulator verification

- `FamilyMemberCard` / `ForwardCoachEmailsCard`: what VoiceOver actually exposes for the combined element (no action vs. unlabeled default action).
- `PublicTab.swift:343-362`: confirm both chevrons read "Reorder <section>".
- `InviteJoinBirthdayConfirmView` in the medium detent at AX3–AX5 on a small phone: is Confirm reachable? (Blocker if not.)
- Wheel pickers clipped to 80–100 pt (`BasicsTab.swift:340-342`, `AthleticsTab.swift:142-159`): legibility at large text, and whether the two adjacent height wheels steal each other's drags.
- Player Profile tabs and `PublicTab` at AX5: how badly the label+field rows, three-button choice rows and the two/three-column preview grids degrade.
- Real contrast of the system-colour text listed above in light, dark and Increase Contrast (ratios here are computed, not measured).
- Whether `HeaderColorPicker` swatches appear under Voice Control "Show names" and Switch Control without the button trait.
- Voice Control matching for the listed label mismatches.
- `ProfileView.swift:246-270`: two buttons in one `List` row (bordered "Update Email" + default-style "Cancel") — check each activates independently with touch and VoiceOver.
- Focus position after the Player Profile tab content swaps, after add/remove travel team, and after the deletion flow changes state (`ProfileView.swift:380-389`).
