# Accessibility findings — Auth, onboarding, gates, legal/help, notifications, app shell

Scope: `Features/Auth`, `Features/Onboarding`, `Features/Landing`, `Features/Legal`, `Features/Help`, `Features/About`,
`Features/AppUpdate`, `Features/Entitlement`, `Features/Guardian`, `Features/Notifications`, `TheRecruitingCompassApp.swift`,
plus the shell it references (`Shared/Navigation/AdaptiveRootView.swift`, `SidebarView.swift`,
`Features/Dashboard/Views/MainTabView.swift`) and the shared pieces these screens depend on (`Core/Theme/AppColors.swift`,
`AppGradients.swift`, `Core/Services/Turnstile/*`, `Shared/Components/AsyncButton.swift`, `Shared/Components/Forms/*`).

Static read only. Nothing was built or run. Contrast ratios are computed from the hex values in `AppColors.swift`
(WCAG relative luminance); system colours (`.red`, `.green`, `.secondary`, `.tertiary`) use Apple's published light-mode values.

Counts: Blocker 0 · High 7 · Medium 16 · Low 9

No finding is rated Blocker: I found no task that is provably impossible with VoiceOver, Voice Control or large text.
Three High items (H2, H3, H7) could turn out to be Blockers on device and are listed under "Needs simulator verification".

---

## High

### [High] Login / signup / password-reset failures are never announced and focus does not move to them
- category: voiceover
- confidence: high
- where: `Features/Auth/Views/LoginView.swift:118-126` (banner), `Features/Auth/ViewModels/LoginViewModel.swift:100,117`;
  `Features/Auth/Views/SignupView.swift:252-264`, `Features/Auth/ViewModels/SignupViewModel.swift:321-325,378,419`;
  `Features/Auth/Views/ForgotPasswordView.swift:39-43,84-90,157-163`; `Features/Auth/Views/ResetPasswordView.swift:69-78`
- what: Every auth failure is surfaced only by setting `errorMessage` and rendering an `ErrorBanner` at the top of the card
  (`if let error = viewModel.errorMessage { ErrorBanner(...) }`). There is no `AccessibilityNotification`/`UIAccessibility.post`
  and no `@AccessibilityFocusState` anywhere in `Features/Auth` except `EmailVerificationView.swift:47-56`. On signup the banner
  ("Please fix the errors below") is at the top of a long `ScrollView` while the button that triggered it is at the bottom, and
  nothing scrolls it into view. The form → "Check Your Email" swap in Forgot Password is equally silent.
- user impact: A VoiceOver user who mistypes a password hears the button go from "Signing in" back to "Sign in to account" and
  nothing else — no indication the sign-in failed or why; a low-vision/zoomed user on signup never sees the banner either.
- fix: Post the message when it is set (`AccessibilityNotification.Announcement(error).post()` in an `.onChange(of: viewModel.errorMessage)`),
  and move focus to the banner with `@AccessibilityFocusState`. On signup wrap the form in `ScrollViewReader` and scroll to the
  banner / first invalid field. `Shared/Components/Forms/FormErrorSummary.swift:63-67` already implements the announce pattern — reuse it.
  Announce the success-state swaps in `ForgotPasswordView` and `ResetPasswordView` the same way.

### [High] Password-reset success auto-dismisses after 3 seconds with no announcement
- category: timing
- confidence: high
- where: `Features/Auth/Views/ResetPasswordView.swift:58-62,192-229`; `Features/Auth/ViewModels/ResetPasswordViewModel.swift:100-112`;
  `Features/Auth/Configuration/PasswordResetConfig.swift:10` (`successCountdownDuration: 3`)
- what: On success the view swaps to `successContent`, starts a 3-second countdown (`"Redirecting to login in \(viewModel.successCountdown)s..."`)
  and then calls `dismiss()`. The swap is not announced, focus is not moved, and the countdown cannot be paused or extended.
- user impact: A VoiceOver or slow reader has 3 seconds to discover "Password Reset!" before the sheet closes; in practice they
  get no confirmation that the password actually changed.
- fix: Remove the auto-redirect (the "Sign In Now" button already exists) or make it ≥ 20 s and cancellable; announce
  "Password reset" on entering `.success` and set accessibility focus on the heading.

### [High] One finding withheld from this file
- This repository is public. One High finding in this area is privacy-sensitive and unverified on device, so it was reported to the maintainer directly instead of being written here.

### [High] Back buttons on every auth screen are ~1.7:1 in Dark Mode (and only ~4.1:1 in light)
- category: dark-mode
- confidence: high
- where: `Features/Auth/Views/LoginView.swift:86`, `SignupView.swift:82`, `ForgotPasswordView.swift:29`, `ResetPasswordView.swift:32`,
  `EmailVerificationView.swift:74`; colour defined at `Core/Theme/AppColors.swift:71`; gradient at `Core/Theme/AppGradients.swift:4-8`
- what: The "Back to Welcome" / "Back" / "Back to Login" buttons sit *outside* the forced-light card, directly on
  `LinearGradient.primaryBackground` (emerald `#10b981` → `#047857`), with `.foregroundStyle(Color.darkSlate)`. `darkSlate` is adaptive
  (`light: slate700 #334155, dark: #cbd5e1`) but the gradient is not, so in Dark Mode the text becomes light slate on bright emerald:
  1.7:1 at the top-leading corner where the button sits. In light mode it is 4.1:1 for 13 pt semibold text (needs 4.5:1).
- user impact: In Dark Mode the only way back from Login, Signup, Forgot Password, Reset Password and Email Verification
  (`navigationBarBackButtonHidden(true)` on all five) is effectively invisible to low-vision users.
- fix: Use a fixed colour that works on emerald in both schemes, e.g. `.foregroundStyle(.white)` (5.5:1 on emerald700; pair with a
  darker gradient start) or put the back button inside the card. Do not use adaptive text tokens on a non-adaptive background.

### [High] Unread notifications: message and timestamp are near-invisible in Dark Mode
- category: dark-mode
- confidence: high
- where: `Features/Notifications/Components/NotificationCard.swift:13-18,33,40-48,55,62`
- what: Unread cards use hard-coded light hex values — `unreadBackground = Color(hex: "#EFF6FF")`, `unreadTitle = "#1E40AF"` — but the
  message, relative date and delete icon use adaptive `.foregroundStyle(.secondary)`. In Dark Mode `.secondary` resolves to a light
  translucent grey, drawn on a near-white `#EFF6FF` card (≈1.2:1). No `colorScheme` override exists in `Features/Notifications`.
- user impact: In Dark Mode a user can read the title of an unread notification but not its body, time, or see the delete button.
- fix: Make the palette adaptive (`Color(light:dark:)` — e.g. dark `unreadBackground` `#172554`, `unreadTitle` `#93C5FD`) or use
  `Color.accentBlue.opacity(0.12)` over `Color.Surface.card` so `.secondary` keeps working.

### [High] Help callouts (tip / warning / important) are white-on-pastel in Dark Mode
- category: dark-mode
- confidence: high
- where: `Features/Help/Components/HelpCallout.swift:26-32,55-57,62`; tokens at `Core/Theme/AppColors.swift:79,82`
- what: Backgrounds are fixed light colours — `.tip: Color(red: 0.85, green: 0.95, blue: 0.88)`, `.warning: Color.warningBackground`
  (`#ffedd5`), `.important: Color.errorBackground` (`#fee2e2`) — while the text is `.foregroundStyle(.primary)`, which is white in
  Dark Mode (≈1.1:1). Only `.info` (`accentBlue.opacity(0.12)`) adapts.
- user impact: In Dark Mode every tip, warning and "Important" box in the Help Center is unreadable — including
  "Account deletion is permanent and cannot be undone" and "Removing a school permanently deletes all coach interactions".
- fix: Use opacity tints of the icon colour (`type.iconColor.opacity(0.12)`) as `.info` already does, or adaptive
  `Color.Surface.warningTint` / `successTint`-style tokens; keep text `.primary`.

### [High] Gate screens are fixed `VStack`s with no `ScrollView` — content truncates at accessibility text sizes
- category: dynamic-type
- confidence: medium
- where: `Features/AppUpdate/Views/UpdateRequiredView.swift:13-51`; `Features/Onboarding/Views/SportGateView.swift:80-146`;
  `Features/Onboarding/Views/PushNotificationPrimingView.swift:13-60` presented with `.presentationDetents([.medium])` only at
  `Features/Onboarding/Views/OnboardingStepTwoView.swift:46-49`; `Features/Auth/Views/BiometricLockView.swift:16-56`
- what: The forced-update screen puts a `.title` heading, a ~45-word `.body` paragraph, a button and a footnote in a non-scrolling
  `VStack` with 32 pt padding. At AX5 the paragraph alone needs well over one screen height on an iPhone, so SwiftUI truncates it.
  The sport gate and the push-priming sheet (locked to a medium detent) have the same structure.
- user impact: A large-text user who hits the forced-update gate cannot read why the app is blocked or which version they need;
  on the push sheet the explanation and possibly "Not now" are cut off with no way to expand the sheet.
- fix: Wrap each in `ScrollView` (keep the CTA in `.safeAreaInset(edge: .bottom)`); give the push sheet
  `.presentationDetents([.medium, .large])`.

---

## Medium

### [Medium] White text on the emerald brand gradient fails contrast on Landing, Update Required and the Face ID lock
- category: color
- confidence: high
- where: `Features/Landing/Views/LandingView.swift:46-63,99-104,136-139`; `Features/Landing/Components/FeatureCard.swift:16-23`;
  `Features/AppUpdate/Views/UpdateRequiredView.swift:21-31,42-48`; `Features/Auth/Views/BiometricLockView.swift:29-31,36-42,47-49`;
  `Features/Onboarding/Views/OnboardingContainerView.swift:116-120`; gradient `Core/Theme/AppGradients.swift:10-14`
- what: `landingBackground` runs emerald500 `#10b981` → emerald600 `#059669`. White on those is 2.5:1 and 3.8:1. Body-size text makes it worse
  with opacity: `Color.white.opacity(0.9)` (hero copy), `0.85` (feature descriptions), `0.75` (`caption2` stat labels), `0.7` (tagline,
  "You're on version …"), `0.8` ("Use Password Instead"). "Use Face ID" is white on `Color.white.opacity(0.25)` over emerald (~2:1).
  "Update Now" is `.borderedProminent` tinted `primaryGreen` (emerald600) on an emerald background, so the button shape has ~1.0–1.5:1
  against its surroundings. Onboarding's "Sign out" is `.foregroundStyle(.secondary)` grey directly on the emerald gradient (~1.4:1).
- user impact: The first screen of the app, the forced-update gate and the biometric lock all fail "Sufficient Contrast" for most of their text.
- fix: Darken the gradient for text-bearing screens (emerald700 `#047857` → emerald800 `#065f46` gives white 5.5–7.7:1), drop the
  opacity modifiers on text, and give "Update Now"/"Use Face ID" a white fill with dark text (as "Sign In" on Landing already does).

### [Medium] Coloured and tertiary text inside cards is below 4.5:1
- category: color
- confidence: high (hex-defined colours) / medium (system colours)
- where:
  - `primaryGreen`/`successGreen` text on white, 3.8:1 — `Features/Auth/Views/SignupView.swift:244`,
    `Features/Auth/Components/PasswordStrengthIndicator.swift:29,57` ("Strong"), `Features/Auth/Views/ResetPasswordView.swift:179-183`
    ("Passwords match"), `Features/About/Views/AboutView.swift:44`, `Features/Help/Components/HelpFeedbackView.swift:66,102`
  - `strengthOrange` (`#f97316`) "Fair", 2.8:1 — `Features/Auth/Components/PasswordStrengthIndicator.swift:27,57`
  - Role cards: white on emerald600 (3.8:1) and `.white.opacity(0.85)` caption on `primaryGreen.opacity(0.85)` — `Features/Auth/Components/RoleSelectionCard.swift:20-26,43-47`
  - Error banner: red600 on red100, 3.95:1 — `Features/Auth/Components/Banner.swift:17,24,48-50`
  - System `.red` caption errors (~3.6:1 on white) — `Features/Auth/Views/SignupView.swift:353,392,416`, `Features/Onboarding/Views/OnboardingStepOneView.swift:230`,
    `Features/Onboarding/Views/SportGateView.swift:120`, `Features/Guardian/Views/GuardianClaimView.swift:25,67`, `Features/Entitlement/Views/PlanView.swift:23`
  - System `.green` title (~2.2:1) — `Features/Guardian/Views/GuardianClaimView.swift:48-50`
  - `.tertiary` text (~1.7:1): "(optional)" and "Helps us find nearby schools" — `Features/Onboarding/Views/OnboardingStepOneView.swift:212-214,232-234`
  - Status pills `.orange`/`.green`/`.blue` text on a 20 % tint of the same colour — `Features/Help/Views/HelpSectionDetailView.swift:465-474`
  - "Optional" badge: white on `iconGray`, which is `#94a3b8` in Dark Mode (2.6:1) — `Features/Help/Components/HelpBadge.swift:28,39`
  - `accentBlue` (`#2563eb`) link on the black login card in Dark Mode, 4.1:1 — `Features/Auth/Views/LoginView.swift:244-250`
  - Legal body copy: slate500 on `Surface.background` `#F4F6FA`, 4.4:1 — `Features/Legal/Components/LegalBodyText.swift:9`, `LegalBulletList.swift:12,15`
- what: e.g. `.foregroundStyle(strengthColor)` where `strengthColor` is `Color.strengthOrange`; `.foregroundStyle(.red)`; `.foregroundStyle(.tertiary)`.
- user impact: Validation errors, password-strength feedback, role descriptions and helper text are hard to read for low-vision users.
- fix: Use the 700-level brand shades for text (`emerald700` 5.5:1, `orange700` 5.2:1, `red700` on red100), replace `.red`/`.green` with
  `Color.errorRed`/`Color.Brand.emerald700`, and replace `.tertiary` with `Color.secondaryText`.

### [Medium] Error/warning banners: dismiss button merged away, wrong `.isHeader` trait, timeout message replaced
- category: voiceover
- confidence: medium
- where: `Features/Auth/Components/Banner.swift:55-70`; `Features/Auth/Views/LoginView.swift:111-126`;
  `Features/Auth/Components/TimeoutBanner.swift:10-11`; `Features/Auth/Components/InfoBanner.swift:33-36`;
  `Features/Auth/Views/ResetPasswordView.swift:248-251`
- what: `Banner` wraps its "Close message" button in `.accessibilityElement(children: .combine)` and then overrides the label
  (`"Error: \(message)"`), so the dismiss control is no longer a separate element. `LoginView` combines again and adds
  `.accessibilityAddTraits(.isHeader)` to both banners; `InfoBanner` also claims `.isHeader`. `TimeoutBanner` overrides the label with
  `"Session timeout warning"`, discarding the visible instruction "You were logged out due to inactivity. Please log in again."
  `ResetPasswordView` passes `onDismiss: {}`, rendering a close button that does nothing.
- user impact: VoiceOver reads errors as "heading, button", a double-tap silently removes the error, and Voice Control users have no
  "Close message" target; the timeout explanation is not read at all.
- fix: Use `.accessibilityElement(children: .contain)`, put the label on the text only, drop `.isHeader`, remove the `TimeoutBanner`
  label override, and make `onDismiss` optional at the `ErrorBanner` call site (pass `nil` in `ResetPasswordView`).

### [Medium] Password-reset screens tell VoiceOver "Email verified successfully"
- category: voiceover
- confidence: high
- where: `Features/Auth/Views/ForgotPasswordView.swift:140,165`; `Features/Auth/Views/ResetPasswordView.swift:194,207,235`;
  `Features/Auth/Components/VerificationStatusIcon.swift:10-21,34-35`; `Features/Auth/Components/InfoBanner.swift:67-94`
- what: Both password screens reuse the email-verification components. `VerificationStatusIcon(state: .verified)` is an accessibility
  element labelled "Email verified successfully" — it is the first thing read on "Check Your Email" (where nothing has been verified)
  and on "Password Reset!". The error state reads "Verification error: …". `InfoBanner(state: .verified)` shows "Email verified! You can
  now access the app" after a password reset, and `InfoBanner(state: .pending, …)` shows "Email not verified — Check … for verification link"
  after requesting a reset link (wrong visible copy as well).
- user impact: Screen-reader users are told their email was verified when they have only been sent a reset link, or have reset a password.
- fix: Give `VerificationStatusIcon` an explicit `accessibilityLabel` parameter (or hide it — the heading beside it already carries the
  meaning) and give the password flows their own banner copy.

### [Medium] Primary buttons look disabled but are not — `.disabled` is applied to the label, not the `Button`
- category: voiceover
- confidence: medium
- where: `Features/Auth/Views/SignupView.swift:670-671`; `Features/Auth/Views/ResetPasswordView.swift:158-159`;
  `Features/Auth/Views/ForgotPasswordView.swift:126-127`; `Features/Auth/Views/EmailVerificationView.swift:171-172`
- what: `.opacity(viewModel.isButtonDisabled ? 0.5 : 1).disabled(viewModel.isButtonDisabled)` is chained on the `HStack` *inside* the
  button's label closure. The `Button` itself stays enabled, so VoiceOver never says "dimmed" and Voice Control/Switch Control treat it
  as actionable. `LoginView` (via `AsyncButton.swift:70-71`) and `ForgotPasswordView.swift:190` do it correctly.
- user impact: Sighted users see a dimmed button; assistive-tech users get an apparently active "Create account" whose activation
  produces only an unannounced banner (see first High finding).
- fix: Move `.disabled(...)` onto the `Button`, or replace these four hand-rolled buttons with `AsyncButton`, which also fixes the
  44 pt minimum and Reduce Motion handling.

### [Medium] Accessibility labels that don't contain the visible text (Voice Control / WCAG 2.5.3)
- category: voice-control
- confidence: medium
- where:
  - `Features/Auth/Views/LoginView.swift:244,254` — shows "Create one now", label "Create account"
  - `Features/Auth/Views/ForgotPasswordView.swift:111,129` — "Send Reset Link" → "Send password reset link"; `:194,200` — "Use Different Email" → "Use a different email address"
  - `Features/Auth/Views/ResetPasswordView.swift:254,264` — "Request New Link" → "Request a new password reset link"
  - `Features/Auth/Views/BiometricLockView.swift:36,44` — "Use Face ID" → "Sign in with Face ID"; `:47,52` — "Use Password Instead" → "Sign in with password"
  - `Features/Auth/ViewModels/EmailVerificationViewModel.swift:81-87,94-102` — "Resend Email (Cooldown)" → "Resend verification email"
  - `Features/Legal/Components/LegalEmailLink.swift:19,25` — shows the address, label "Email support at therecruitingcompass dot com"
- what: The override replaces the visible words rather than extending them, and none set `accessibilityInputLabels`.
- user impact: A Voice Control user saying "Tap Use Face ID" or "Tap Create one now" gets no match and must fall back to "Show names"/numbers.
- fix: Drop the overrides where the visible text is already clear, or keep them and add
  `.accessibilityInputLabels(["Use Face ID", "Face ID"])` etc. The spelled-out email label is unnecessary — VoiceOver reads addresses correctly.

### [Medium] Hit targets under 44 pt on required first-run controls
- category: hit-target
- confidence: medium
- where:
  - Back buttons with no minimum frame (footnote text, ~18 pt tall): `Features/Auth/Views/LoginView.swift:78-87`,
    `SignupView.swift:74-83`, `ForgotPasswordView.swift:21-30`; "Change Role" `SignupView.swift:221-232`
  - Terms checkbox is an 18 pt image; "Terms of Service"/"Privacy Policy" are bare footnote text: `Features/Auth/Components/TermsCheckbox.swift:11-20,33-38,47-52`
    (the row's `frame(minHeight: 44)` at `:60` does not enlarge the individual buttons)
  - `frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` applied *outside* the `Button`, which enlarges layout but not the tappable label:
    `Features/Auth/Components/PasswordFormField.swift:52-58` (show/hide password), `Features/Guardian/Views/GuardianPendingBanner.swift:43-52`,
    `Features/Legal/Components/LegalEmailLink.swift:11-24`
  - `Features/Onboarding/Views/OnboardingStepOneView.swift:126-132` ("Change sport" xmark), `:185-189` ("Other year...")
  - "Sign out": `Features/Onboarding/Views/OnboardingContainerView.swift:116-120`, `Features/Onboarding/Views/SportGateView.swift:83-87`
  - `.controlSize(.small)` Add / Not a fit: `Features/Onboarding/Views/OnboardingStepTwoView.swift:225-239`; "Not now" `PushNotificationPrimingView.swift:49-56`
  - Default-height bordered buttons: `Features/Guardian/Views/GuardianClaimView.swift:53,74,77-85,124-132`, `Features/Onboarding/Views/OnboardingContainerView.swift:102-105`
  - `Features/Notifications/Components/NotificationToggleChip.swift:13-25` (~36 pt), `NotificationBulkActions.swift:14-30`, `Features/Help/Components/HelpFeedbackView.swift:85-89`
- what: e.g. `Button(action: { isChecked.toggle() }) { Image(systemName: ...).font(.system(size: checkboxSize)) }` with no frame.
- user impact: Users with tremor or limited dexterity struggle to hit the mandatory terms checkbox, the back buttons and the password-visibility toggle.
- fix: Put `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` *inside* each button's label; make the whole terms row
  (checkbox + "I agree to the") one toggle button.

### [Medium] Sport gate "Continue" is a full-width bar of which only the word is tappable
- category: hit-target
- confidence: medium
- where: `Features/Onboarding/Views/SportGateView.swift:124-142`
- what: The label is just `Text("Continue")`; `.frame(maxWidth: .infinity).frame(height: 48).background(...).clipShape(...)` are applied
  to the `Button` from outside, so the coloured 48 pt bar is decoration and the hit region is the text's bounds. The fixed
  `frame(height: 48)` also clips the label at accessibility text sizes.
- user impact: On a screen that blocks the whole app, taps on most of the visible button do nothing.
- fix: Move frame/background/clip into the label (or use `AsyncButton(title: "Continue", isLoading: viewModel.isSaving, isDisabled: !viewModel.canSave)`),
  with `minHeight` instead of `height`.

### [Medium] Dynamic Type: rows that cannot reflow, truncated essential text, fixed heights
- category: dynamic-type
- confidence: medium
- where:
  - `Features/Auth/Components/TermsCheckbox.swift:32-55` — `HStack(spacing: 0)` of "Terms of Service" + " and " + "Privacy Policy" cannot wrap
  - `Features/Auth/Components/RoleSelectionCard.swift:27` — role description `.lineLimit(2)`
  - Fixed `frame(height:)` on text-bearing button labels: `Features/Onboarding/Views/OnboardingStepOneView.swift:259`,
    `OnboardingStepTwoView.swift:166`, `PushNotificationPrimingView.swift:44`, `SportGateView.swift:138`
  - `Features/Onboarding/Views/OnboardingStepTwoView.swift:185-187,224-240,243` — recommendation card fixed `frame(width: 260)`,
    school name `.lineLimit(2)`, two side-by-side small buttons
  - `Features/Help/Views/HelpCenterView.swift:16-19,74` — always-two-column grid, description `.lineLimit(3)`
  - `Features/Notifications/Components/NotificationCard.swift:34,43` — title `.lineLimit(2)`, message `.lineLimit(3)`, and the tap
    navigates to the linked record (`NotificationsListViewModel.swift:266-272`), so the full message is never shown;
    `NotificationBulkActions.swift:13-31` — two long labels in one `HStack`
  - `Features/Help/Components/HelpStepCard.swift:19-22` — `.title2` number in a fixed 32×32 frame; `Features/AppUpdate/Views/WhatsNewView.swift:18-20` icon `frame(width: 36)`
- what: e.g. `.frame(maxWidth: .infinity).frame(height: 50)` on a label containing `Text("Continue").font(.body.weight(.semibold))`.
- user impact: At AX sizes the terms links clip, role and notification text is cut off with no way to read the rest, and onboarding button labels overflow their fill.
- fix: `minHeight` instead of `height`; `ViewThatFits`/`dynamicTypeSize.isAccessibilitySize` branches to stack vertically (terms row,
  bulk actions, card buttons, help grid → one column); remove `lineLimit` on essential copy; `@ScaledMetric` for the fixed circles.

### [Medium] Email-verification screen flips state every 2–10 s while polling
- category: timing
- confidence: medium
- where: `Features/Auth/ViewModels/EmailVerificationViewModel.swift:160-167,89-102`; `Features/Auth/Views/EmailVerificationView.swift:89-94,160-175`;
  `Features/Auth/Components/InfoBanner.swift:67-94`
- what: Each poll sets `verificationState = .checking` then back to `.pending`, which swaps the status icon, the headline/subtitle,
  the banner ("Email not verified" ↔ "Checking verification..." / "Polling for verification status...") and the button
  (label becomes "Checking verification status", `isButtonDisabled` true). There is no way to pause it.
- user impact: Text under the VoiceOver cursor keeps changing and the resend button is intermittently dimmed; for sighted users the card content blinks continuously.
- fix: Poll without changing visible state (keep `.pending` and show `.checking` only for user-initiated checks), or mark the banner
  `.updatesFrequently` and keep the button label/enabled state stable.

### [Medium] Onboarding school recommendations: ambiguous buttons, focus lost on add/dismiss, nothing announced
- category: voiceover
- confidence: medium
- where: `Features/Onboarding/Views/OnboardingStepTwoView.swift:105-123,133-145,225-239`;
  `Features/Onboarding/ViewModels/OnboardingV2ViewModel.swift:257-258,269-272`; `Features/Onboarding/Views/OnboardingStepOneView.swift:62-66,87-90`
- what: Every card exposes identical "Add" and "Not a fit" buttons with no school name. Activating either removes the card
  (`recommendations.removeAll { ... }`), so the focused element disappears; the "N schools added to your list" banner is not
  announced, and after the first add a push-permission sheet appears unprompted. Step 1 has the same focus loss when picking a sport
  (the list is replaced by a badge).
- user impact: A VoiceOver user cannot tell which school "Add" refers to out of context, gets no confirmation it was added, and is dropped into an unexpected sheet.
- fix: `.accessibilityLabel("Add \(recommendation.name)")` + `.accessibilityInputLabels(["Add"])` (same for "Not a fit"); announce
  "\(name) added" and move focus to the next card or the banner; group card text with `.accessibilityElement(children: .combine)`.

### [Medium] Secondary-flow results and errors are silent
- category: voiceover
- confidence: high
- where: `Features/Guardian/Views/GuardianClaimView.swift:18-30,64-68` (loading → loaded/confirmed/error, sign-in error);
  `Features/Guardian/Views/GuardianPendingBanner.swift:37-41` (resend result, always blue whether success or failure);
  `Features/Onboarding/Views/SportGateView.swift:117-121`; `Features/Onboarding/Views/OnboardingStepOneView.swift:227-230`;
  `Features/About/Views/AboutView.swift:40-55`; `Features/Help/Components/HelpFeedbackView.swift:55-68`;
  `Features/Entitlement/Views/PlanView.swift:20-23`; `Features/Notifications/Views/NotificationsListView.swift:33-36`
- what: Each renders a new `Text`/`Label` on completion with no announcement or focus move. In `GuardianClaimView` the error state is a
  bare red `Text(message)` with no "Error" prefix, icon or retry.
- user impact: After "Confirm", "Resend confirmation email", "Send Message" or thumbs-up/down, VoiceOver users don't learn whether it worked.
- fix: `AccessibilityNotification.Announcement(...)` on each state change (a small shared `.announce(on:)` modifier would cover all of these);
  prefix errors with an icon + "Error:" as `LoginFormField` does.

### [Medium] Help content: section headings aren't headings; FAQ expanded state isn't exposed
- category: voiceover
- confidence: high
- where: `Features/Help/Components/HelpSectionHeader.swift:15-27` (used ~30 times in `Features/Help/Views/HelpSectionDetailView.swift`);
  `HelpSectionDetailView.swift:339-343` (glossary letters), `:448-450` (phase titles); FAQ rows `:375-394`
- what: `HelpSectionHeader` combines title + badge and sets a label but never adds `.isHeader`. FAQ questions are buttons whose only
  state cue is the hint ("Expands the answer"/"Collapses the answer") — no `accessibilityValue` or `.isSelected`.
- user impact: VoiceOver users can't jump between help sections with the Headings rotor on long articles, and (with hints off) can't tell whether an FAQ answer is open.
- fix: `.accessibilityAddTraits(.isHeader)` on `HelpSectionHeader`, glossary letters and phase titles;
  `.accessibilityValue(expandedId == entry.id ? "Expanded" : "Collapsed")` on FAQ rows (or use `DisclosureGroup`).

### [Medium] Notification card merges a nested delete button; there is no mark-as-read control at all
- category: voiceover
- confidence: low
- where: `Features/Notifications/Components/NotificationCard.swift:6,23,53-59,72-77`
- what: A "Delete notification" `Button` is nested inside the card's outer `Button`, and the whole thing is
  `.accessibilityElement(children: .combine)` with an overriding label and no `accessibilityAction`. `onMarkRead` is accepted (`:6`) but
  never used in `body`. Whether SwiftUI surfaces the nested button as a custom action here is not determinable statically.
- user impact: VoiceOver/Switch Control users may be unable to delete a single notification, and no user can mark one read without opening it.
- fix: Remove the nesting (overlay the delete button as a sibling) and add explicit
  `.accessibilityAction(named: "Delete") { onDelete() }` and `.accessibilityAction(named: "Mark as read") { onMarkRead() }`.

### [Medium] Text-field accessibility value is replaced by the error string
- category: forms
- confidence: low
- where: `Features/Auth/Components/LoginFormField.swift:47-48,79-84`; `Features/Auth/Components/PasswordFormField.swift:29-30,70-75`
- what: `.accessibilityValue(error.map { "Error: \($0)" } ?? "")` is set on the `TextField`/`SecureField`. A text field's value is
  normally its contents; this override may stop VoiceOver reading what was typed (always, since the non-error value is `""`), and
  in the error case reads the error instead of the text. The same error is then read again by the separate `Text` below.
- user impact: A VoiceOver user correcting an invalid email may be unable to hear what is currently in the field.
- fix: Leave the value alone; expose the error via `.accessibilityHint(error ?? "")` or by appending to the label, and keep the visible error `Text` as the single source.

### [Medium] Four of the five forced-light cards rely on `.colorScheme(.light)` alone
- category: dark-mode
- confidence: low
- where: `Features/Auth/Views/ForgotPasswordView.swift:45-47`, `ResetPasswordView.swift:48-50`, `EmailVerificationView.swift:106-108`,
  `Features/Onboarding/Views/OnboardingContainerView.swift:52-54`; compare `Features/Auth/Views/SignupView.swift:34-44`
- what: `SignupView` carries both `.colorScheme(.light)` and, per its own comment, a later fix `.environment(\.colorScheme, .light)` because
  "adaptive colors inside it (LoginFormField's secondarySystemBackground/.primary) still followed the system appearance — rendering
  black-on-white input fields". The other cards host the same `LoginFormField`/`PasswordFormField` (and, in onboarding, `.secondary`,
  `secondarySystemGroupedBackground`, a segmented `Picker`) on `Color.white.opacity(0.95)` without that second modifier.
- user impact: If the Signup bug reproduces there, Dark Mode users get dark input fields / light text on a white card in Forgot Password, Reset Password and onboarding.
- fix: Verify in the simulator; if reproduced, apply the same `.environment(\.colorScheme, .light)` (ideally via one shared `AuthCard` container).

---

## Low

### [Low] Screen titles lack `.isHeader` (while banners wrongly have it)
- category: voiceover
- confidence: high
- where: `Features/Landing/Views/LandingView.swift:46`; `Features/Auth/Views/SignupView.swift:111`; `ForgotPasswordView.swift:74,143`;
  `ResetPasswordView.swift:94,197,238`; `BiometricLockView.swift:29`; `Features/Onboarding/Views/SportGateView.swift:93`;
  `PushNotificationPrimingView.swift:22`; `Features/Help/Views/HelpCenterView.swift:39`; `Features/Guardian/Views/GuardianPendingBanner.swift:27`
- what: e.g. `Text("Select Your Role").font(.title3.weight(.semibold))` with no trait. `LoginView` and the signup form step have no title
  at all (logo is hidden), so the first thing read is "Back to welcome screen".
- user impact: No heading to orient on or jump to; screen changes within a card (role → form, form → success) are harder to notice.
- fix: Add `.accessibilityAddTraits(.isHeader)`; give Login and the signup form a visible or `accessibilityLabel`-only heading.

### [Low] VoiceOver noise, wrong hints and duplicated labels
- category: voiceover
- confidence: high
- where:
  - Wrong hint: `Features/Auth/Views/LoginView.swift:88-89` (label "Back to welcome screen", hint "Returns to the login screen");
    `SignupView.swift:84` says "Back to welcome screen" even when Signup was pushed from Login
  - Hints that name the gesture: `SignupView.swift:674`, `Features/Auth/Components/TermsCheckbox.swift:24`, `Features/Notifications/Components/NotificationCard.swift:76`
  - Standalone "•" elements: `Features/Legal/Components/LegalBulletList.swift:10-12`, `Features/Help/Views/HelpSectionDetailView.swift:422-424`
  - Decorative images not hidden: `Features/Onboarding/Views/OnboardingStepOneView.swift:73`, `OnboardingContainerView.swift:93-95`,
    `OnboardingStepTwoView.swift:83-85,135-136`, `PushNotificationPrimingView.swift:16-19`, `Features/Help/Views/HelpSectionDetailView.swift:435-438`
  - "M"/"W" gender badge read as a bare letter: `Features/Onboarding/Views/OnboardingStepOneView.swift:97`
  - "selected" spoken twice (in label and as trait): `Features/Notifications/Components/NotificationToggleChip.swift:9,26-27`; emoji read as part of chip names (`NotificationFilterChips.swift:34`)
  - "5m ago"/"3h ago" abbreviations in the spoken label: `Features/Notifications/Components/NotificationCard.swift:90,123-125`
  - Duplicate visible + spoken label: Zip Code is labelled twice (`Features/Auth/Views/SignupView.swift:441-452`), Date of Birth text + picker label (`:329,335`)
  - Unlocalised values "checked"/"Selected"/"Not selected": `LoginView.swift:188`, `RoleSelectionCard.swift:52`, `TermsCheckbox.swift:22`
- fix: Correct the hints, combine bullet rows, `.accessibilityHidden(true)` on decorative images, spell out "Men's"/"Women's",
  drop ", selected" from the chip label, use `Date.RelativeFormatStyle` for the spoken date.

### [Low] Animations not gated on Reduce Motion
- category: motion
- confidence: high
- where: `Features/Auth/Components/PasswordStrengthIndicator.swift:71`; `Features/Auth/ViewModels/SignupViewModel.swift:190,194`;
  `Features/Auth/Views/LoginView.swift:48`; `Features/Onboarding/Views/OnboardingContainerView.swift:166`;
  `Features/Help/Views/HelpSectionDetailView.swift:376`
- what: Unconditional `withAnimation`/`.animation` (bar growth, role → form swap, keyboard scroll, step change, FAQ expand). All are short fades/resizes.
- user impact: Minor; no large-scale motion found in this area.
- fix: Read `@Environment(\.accessibilityReduceMotion)` and pass `nil` — as `TheRecruitingCompassApp.swift:93-100`, `VerificationStatusIcon` and `CompassLoadingAnimation` already do.

### [Low] Read vs unread notifications differ only by colour and font weight
- category: color
- confidence: medium
- where: `Features/Notifications/Components/NotificationCard.swift:32-33,62-68`
- what: Unread = blue title, blue-tinted background, blue 4 pt bar, semibold; read = default colours, regular weight. No dot/icon/text.
  (VoiceOver is fine: the label starts with "Read"/"Unread".)
- user impact: With Differentiate Without Colour or colour-vision deficiency, unread items are distinguished only by a subtle weight change.
- fix: Add an unread dot or "New" text badge beside the title.

### [Low] Form polish
- category: forms
- confidence: high
- where: `Features/Auth/Components/PasswordFormField.swift:22-34` (no `textContentType(.newPassword)`; toggling visibility swaps
  `SecureField`/`TextField` and drops keyboard focus); `Features/Auth/Views/SignupView.swift:449-464` (zip has no `.postalCode`);
  `Features/Onboarding/Views/OnboardingStepOneView.swift:59,143` (required fields unmarked; "Continue" is just dimmed);
  `Features/About/Views/AboutView.swift:25-32` (placeholder-only message field); `Features/Auth/Views/ForgotPasswordView.swift:92-102` (no submit action)
- user impact: Password managers don't offer a strong password on reset; users aren't told why "Continue" is disabled.
- fix: Add content types, mark required fields in the label ("Primary Sport, required"), add a visible label to the About message field.

### [Low] Fixed-size icon fonts
- category: dynamic-type
- confidence: high
- where: `Features/Onboarding/Views/OnboardingStepTwoView.swift:84` (`.font(.system(size: 40))`),
  `Features/Onboarding/Views/PushNotificationPrimingView.swift:17` (`size: 56`); two-step manual sizing at
  `Features/Auth/Views/ForgotPasswordView.swift:59-61,67` and `Features/Notifications/Components/NotificationEmptyState.swift:6-8,15`
- what: Decorative icons only; the rest of the area uses `@ScaledMetric`.
- fix: `@ScaledMetric(relativeTo: .largeTitle)` as in `ResetPasswordView.swift:10`.

### [Low] Invisible captcha has no fallback path
- category: forms
- confidence: low
- where: `Core/Services/Turnstile/TurnstileTokenProvider.swift:104-112,164-189`; `TheRecruitingCompassApp.swift:120-127`;
  message at `Core/Models/AuthError.swift:97-98`
- what: The Turnstile widget is rendered `size: 'invisible'` in a 1×1, `allowsHitTesting(false)`, `accessibilityHidden(true)` web view.
  That is the right call for accessibility (no puzzle to solve). But if Cloudflare ever fails or wants interaction, the only outcome is
  "Couldn't verify you're human. Please try again." after up to 20 s, shown in the unannounced banner, with no alternative route.
- user impact: Any user Cloudflare scores as suspicious is locked out of login, signup and password reset with no accessible alternative.
- fix: Announce the failure (first High finding) and add a support/contact link to the captcha error; confirm the Cloudflare widget mode is "Invisible"/non-interactive.

### [Low] "Face ID" is hard-coded
- category: voiceover
- confidence: high
- where: `Features/Auth/Views/BiometricLockView.swift:24-44`; `TheRecruitingCompassApp.swift:146,160`
- what: Icon `faceid`, "Sign in with Face ID", "Use Face ID", "Enable Face ID?" regardless of `LABiometryType`.
- user impact: On Touch ID devices (iPhone SE, most iPads) the spoken and visible names are wrong.
- fix: Derive the name and symbol from `LAContext().biometryType`.

### [Low] Onboarding large title sits on the emerald gradient
- category: dark-mode
- confidence: low
- where: `Features/Onboarding/Views/OnboardingStepOneView.swift:30-31`; `OnboardingStepTwoView.swift:36-37`; `OnboardingContainerView.swift:30-34`
- what: `.navigationTitle(...)` with `.large` display mode renders in the `NavigationStack` bar, outside the forced-light card, over
  `primaryBackground`. In Dark Mode the title is white on emerald500 (≈2.5:1 at the leading edge).
- fix: Move the title into the card as a `Text` with `.isHeader`, or set a toolbar colour scheme / background for the bar.

---

## Done well

- `LoginFormField` / `PasswordFormField`: persistent visible label above the field (not placeholder-only), label mirrored onto the control,
  `.contain` grouping, correct `textContentType`/keyboard for email and password, inline error text with "Error:" prefix
  (`Features/Auth/Components/LoginFormField.swift:57-88`). Keep this structure.
- Keyboard chaining and the Previous/Next/Done accessory are labelled (`Shared/Components/Forms/KeyboardFieldNavigation.swift:26,36`).
- `AsyncButton` (used for Login "Sign In"): `.disabled` on the button itself, loading label/hint swap, `.updatesFrequently`,
  48/56 pt min height, press animation gated on Reduce Motion (`Shared/Components/AsyncButton.swift:70-74,77-79,131-140`).
- Reduce Motion honoured for the root auth/session transitions, the verified-checkmark spring and the splash compass
  (`TheRecruitingCompassApp.swift:93-100`, `VerificationStatusIcon.swift:62-66`, `CompassLoadingAnimation.swift:23-31`).
- `EmailVerificationView` announces verified/error (`:43-58`) — the only auth screen that does; copy this pattern.
- `UpdateRequiredView` replaces the root instead of overlaying it, with a header trait and a hint on "Update Now"; app-level sheets are
  closed when the gate appears (`TheRecruitingCompassApp.swift:41-45,131-137`).
- Captcha is invisible/non-interactive and hidden from the accessibility tree — no puzzle for AT users.
- Decorative icons are consistently `.accessibilityHidden(true)` across Auth, Landing and Help; almost every icon size uses `@ScaledMetric`;
  no fixed text font sizes anywhere in the area.
- Password strength, password match, priority badges and role selection all pair colour with text or an icon.
- Password strength and unmet requirements are exposed as readable labels (`PasswordStrengthIndicator.swift:59-60,91-92`).
- Cooldown buttons expose the remaining seconds in their label/hint (`ForgotPasswordView.swift:227-232`, `EmailVerificationViewModel.swift:104-112`).
- Notification cards have a complete spoken label (read state, priority, type, title, message, time); filter chips carry `.isSelected`;
  the empty state is one combined element.
- Legal documents: every section/subsection is a real header, body text is semantic `.body` with `fixedSize(vertical:)`, colours are adaptive.
- Help cards, step cards, callouts and glossary entries are combined into single well-labelled elements ("Step 1: …", "Tip: …").
- Onboarding errors use system `.alert`, which VoiceOver announces and focuses.
- Shell: stock `TabView` / `NavigationSplitView` / `List(selection:)` with text labels; no custom tab bar to maintain.

## Needs simulator verification

1. (withheld — see the note under High)
2. **Dimmed buttons (Medium):** confirm "Create Account", "Reset Password", "Send Reset Link" and the verification button remain
   activatable and are not read as "dimmed" when `.disabled` is on the label.
3. **Field value override (Medium, low confidence):** focus the email field with text typed, with and without a validation error — does
   VoiceOver read the typed text?
4. **Forced-light cards (Medium, low confidence):** Forgot Password, Reset Password, Email Verification and onboarding step 1 in Dark Mode —
   are field backgrounds/text light-scheme, as on Signup?
5. **Update gate, sport gate, push-priming sheet, biometric lock at AX5** on a small device (iPhone SE / 16e): is all text readable and are both buttons reachable? If a button is pushed off-screen this is a Blocker.
6. **Banner activation:** does double-tapping the combined error banner dismiss it; is "Close message" reachable by Voice Control?
7. **Notification card:** does VoiceOver's Actions rotor offer "Delete notification" on the combined card?
8. **Outside-the-button frames:** tap inside the 44 pt area but off the glyph on the show/hide-password eye, "Resend confirmation email",
   the legal email link, and anywhere on the sport-gate "Continue" bar except the word.
9. **Default `.bordered`/`.borderedProminent` heights** on the current OS (GuardianClaimView, onboarding "Try Again") — 44 pt or not?
10. **Email-verification polling:** how visible is the pending ↔ checking flip, and does VoiceOver re-read the focused element each cycle?
11. **Voice Control:** say the visible text for each mismatch listed ("Tap Create one now", "Tap Use Face ID", …).
12. **Onboarding "Sign out" and large title** rendering on the emerald gradient in light and dark.
13. **Turnstile under assistive tech:** confirm login succeeds with VoiceOver, Switch Control and Voice Control active (Cloudflare scoring is opaque).
14. `LoginView(timeoutReason:)` is never called with a reason anywhere in the source, so `TimeoutBanner` appears unreachable — confirm whether the session-timeout path still uses it (`Shared/Components/SessionExpiredSheet.swift` seems to have replaced it).

Not reviewed (outside the assigned folders, reached from this path): `Features/Family/Views/ParentOnboardingWizardView.swift`,
`InviteJoinView.swift`, `InviteJoinBirthdayConfirmView.swift` — they use the same forced-light card pattern and likely share the
back-button, banner and dimmed-button findings above.
