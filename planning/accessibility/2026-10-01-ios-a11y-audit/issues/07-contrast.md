## Problem

Text contrast falls below WCAG AA (4.5:1 for body text, 3:1 for large text) in many places in both light and dark mode. Most of it traces back to a handful of tokens in `Core/Theme/AppColors.swift`, so the fix is mostly central.

The web app has the same palette and the same failures — see recruiting-compass-web#1083, which proposes replacement shades with computed ratios. **Decide the token changes once for both platforms.**

### Token-level ratios (computed from the hex values)

Light mode, text on `Surface.card` `#FAFBFD` / white:

| Token | Ratio | Uses |
|---|---|---|
| `primaryGreen` / `successGreen` / `Semantic.success` (`emerald600 #059669`) as text | 3.6 / 3.8 — fail | 20 as text |
| White text on `emerald600` fill | 3.8 — fail | 9 as fill |
| `Color.Text.muted` `#7A8BA0` | 3.4 / 3.5 — fail | 16 |
| `secondaryText` (`slate500 #64748b`) | 4.6 on card, 4.4 on `Surface.background`, 4.05 on `Surface.muted` — borderline | 97 |
| `errorRed` (`red600`) | 4.7 on card, 4.5 on background, 3.95 on `red100` | 29 as text |
| `Brand.blue500`, `emerald500`, `orange500/600`, `red500`, `purple500`, `sky500`, `pink500`, `warningCTA` as text or under white text | 2.3 – 4.2 — fail | various |
| Tinted badges, 600 text on 100 fill | emerald 3.3, orange 3.1, red 4.0, blue 4.2 — fail (700 on 100 passes: 4.5 – 6.0) | — |
| System `.red` / `.green` / `.orange` / `.blue` / `.yellow` as text | roughly 2.2 – 4.0 — fail | 75 |
| `.foregroundStyle(.tertiary)` text | about 1.7 – 2 | 24 |

Dark mode, text on `Surface.card` `#1E1E1E`:

| Token | Ratio | Uses |
|---|---|---|
| `accentBlue` / `actionPrimary` (`blue600 #2563eb`) — **not adaptive** | 3.2 — fail | 53 as text |
| `errorRed` (`red600`) — **not adaptive** | 3.5 — fail | 29 as text |
| `successGreen` (`emerald600`) — **not adaptive** | 4.4 — fail | 20 as text |
| `warningOrange` (`orange700`) — **not adaptive** | 3.2 — fail | — |
| `Color.Text.muted` `#888888` on `Surface.muted` | 4.05 — fail | — |

`darkSlate`, `secondaryText`, `amberGold` and the `Surface.*` / `Text.*` tokens are adaptive; the four above are plain `Color.Brand.*600` constants.

### Screens where the automated Xcode audit measured failures

Xcode's `performAccessibilityAudit` on the simulator (iPhone 17, iOS 27.2) reported **168 "Contrast failed"** and 227 "Contrast nearly passed" items across 28 screens in light, dark and largest-text runs. "Contrast failed" per screen:

| Screen | Light | Dark | Largest-text |
|---|---|---|---|
| dashboard | 16 | 15 | 4 |
| landing | 11 | 11 | 2 |
| coaches-detail | 10 | 7 | 0 |
| notifications | 4 | 10 | 0 |
| deadlines | 7 | 5 | 0 |
| events | 2 | 1 | 7 |
| signup-role | 4 | 5 | 1 |
| signup-player | 2 | 3 | 1 |
| add-new-school | 2 | 2 | 1 |
| interactions-list | 2 | 0 | 3 |
| schools-list | 2 | 1 | 1 |
| schools-detail | 2 | 2 | 0 |
| public-profile | 2 | 1 | 1 |
| documents | 2 | 0 | 2 |
| signup-parent | 1 | 2 | 1 |
| more | 1 | 1 | 0 |
| analytics | 1 | 1 | 0 |
| coaches-list | 1 | 0 | 1 |
| forgot-password | 0 | 1 | 1 |
| interactions-detail | 0 | 0 | 1 |
| login | 0 | 1 | 0 |

Counts are an upper bound: a few items are elements partly covered by the floating tab bar or the sticky email-verification banner at the moment of capture. Largest-text counts are lower because large text only needs 3:1.

Notable confirmations on device: the Back button on login, forgot password and signup fails in dark mode; unread notification body and timestamps fail in dark mode (4 items in light, 10 in dark); the dashboard Getting Started checklist text (completed, struck-through items) fails in both; 11 text elements on the landing screen fail in both.

### Specific defects beyond the tokens

**Adaptive text on a fixed light background (unreadable in dark mode):**
- Auth Back buttons on the green gradient — `darkSlate` on `LinearGradient.primaryBackground`: `LoginView.swift:86`, `SignupView.swift:82`, `ForgotPasswordView.swift:29`, `ResetPasswordView.swift:32`, `EmailVerificationView.swift:74`. Measured "Contrast failed" in dark mode on the three that were audited (login, forgot password, signup); "nearly passed" in light.
- Unread notifications — `Features/Notifications/Components/NotificationCard.swift:13-18,33,40-48,55,62` (hard-coded `#EFF6FF` background with `.secondary` text).
- Help callouts — `Features/Help/Components/HelpCallout.swift:26-32,55-57,62` (tip/warning/important boxes with `.primary` text on fixed pastels, including "Account deletion is permanent…").
- Coach alerts and overdue card — `Features/Coaches/Components/CoachAlertsSection.swift:39` on `:13,20,45`; `CoachStatsGrid.swift:89` on `:103`.
- `Shared/Components/InterestResultCard.swift:22,34`; `Shared/Components/OfflineBanner.swift:9,13,17` (white on `secondaryText`, which becomes `#94a3b8` in dark; mounted app-wide).
- Login card in dark mode: the wordmark and tagline in the `LogoStacked` image are dark green/brown on a black card (seen in the dark-mode screenshot).

**White text on a fill that turns light in dark mode:**
- Medium-urgency action-item button — `Features/Dashboard/Components/ActionItemCard.swift:88-89` (`amberGold` becomes `#fbbf24`, about 1.6:1).
- "Recruiting Coordinator" role badge — `Features/Coaches/Components/CoachCardView.swift:119-122` with `CoachRole.swift:20`.
- `Features/Events/Components/EventDetail/EventCoachCard.swift:48-50`; `ParentOnboardingBanner.swift:80-86,99-105`.

**White text on the green brand gradient (light and dark):**
- Landing — `Features/Landing/Views/LandingView.swift:46-63,99-104,136-139`, `Features/Landing/Components/FeatureCard.swift:16-23` (white at 0.7–0.9 opacity on `emerald500 → emerald600`, 2.5 – 3.8:1). The automated audit flagged 13 text elements on this screen.
- Update-required gate and Face ID lock — `Features/AppUpdate/Views/UpdateRequiredView.swift:21-31,42-48`, `Features/Auth/Views/BiometricLockView.swift:29-31,36-42,47-49`.
- Role cards — `Features/Auth/Components/RoleSelectionCard.swift:20-26,43-47`.

**Other:**
- "Clear all" in the active school filters is white on the light grouped background (about 1.1:1) — `Shared/Components/FilterChipContainer.swift:42-58` as used by `SchoolActiveFilterChips.swift:9-18`.
- Completeness percentage in `.yellow` / `.green` / `.red` on a white card — `Features/Preferences/Components/PlayerCompletenessCard.swift:10-16,25-28`.
- White on system `.blue` / `.red` chips and buttons — `Shared/Components/FilterChip.swift:65-80`, `FilterMenuButton.swift:49,58`, `FormErrorSummary.swift:57`, `PreferenceRow.swift:26-33`.
- Red caption errors via `.foregroundStyle(.red)` — `Shared/Components/Forms/FieldError.swift:19,24` (every form-field error) and many call sites.
- Password strength "Fair" in `strengthOrange` (2.8:1) — `Features/Auth/Components/PasswordStrengthIndicator.swift:27,57`.
- Per-area lists of status pills and tinted badges are in the audit's area reports.

## Fix

1. In `AppColors.swift`, give `accentBlue`, `errorRed`, `successGreen`/`primaryGreen` and `warningOrange` dark variants (400-level shades) via `Color(light:dark:)`, the way `amberGold` already works. Knock-on: an adaptive token can no longer be used as a **fill** under white text — add separate fill tokens that stay dark in both schemes.
2. Use 700-level shades for coloured text in light mode (`emerald700`, `orange700`, `red700`); darken `Color.Text.muted`; replace `.tertiary` text with `.secondary`.
3. Route all pills through `BadgeColor` (700 on 100) and make it adaptive.
4. Replace raw system colours used as text with tokens.
5. Never put an adaptive text token on a non-adaptive background: make the pastel backgrounds adaptive (`Surface.warningTint`-style) or pin the text colour.
6. Text-bearing gradients: use `emerald700 → emerald800` (white is 5.5 – 7.7:1) and drop the text opacity.

## Done when

The automated audit (`AccessibilityAuditTests`) reports no "Contrast failed" items on the audited screens in light and dark mode.

## Evidence

Ratios are computed from hex values. The landing, auth, signup and signed-in screen failures were measured by Xcode's accessibility audit on the simulator. The remaining per-file items come from source review and are not individually measured. Severity: **High** in aggregate (blocks the Sufficient Contrast and Dark Interface App Store labels).

Part of the iOS accessibility audit — tracking issue: TRACKING
