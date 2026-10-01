# iOS accessibility audit — 2026-10-01

**Verdict: the app is not ready to declare any App Store Accessibility Nutrition Label, and "WCAG AA compliant" is
not currently true.** Basic labelling is good (796 `accessibilityLabel` uses, semantic fonts almost everywhere,
decorative icons hidden), but there are four blockers and a set of shared root causes behind most of the rest.

Audited commit `d775d198` (origin/main). The issues below are drafted in [`issues/`](issues/) and **not yet filed** —
run [`file-issues.sh`](file-issues.sh) to create them on GitHub with a tracking issue.

## How it was done

1. **Static review** of every View/Component file (about 90k lines), split into six areas — reports in
   [`areas/`](areas/). About 190 raw findings: 4 Blocker, 44 High, 84 Medium, 56 Low, with overlap between areas.
   Line numbers in the area reports are against the main checkout at `f59b561c` and can be a few lines off.
2. **Contrast maths** from the hex values in `Core/Theme/AppColors.swift`.
3. **Xcode's automated audit** (`performAccessibilityAudit`) on the simulator in light, dark and largest-text runs,
   over 28 screens: 759 issues — see [`automated-audit.md`](automated-audit.md). The test that produced it is
   `TheRecruitingCompassUITests/E2E/AccessibilityAuditTests.swift` (opt-in, not a CI gate).
4. **Spot checks**: the top findings were re-read in source, and the accessibility trees captured by the automated
   run were used to confirm or refute claims that static review could not settle.

**Not done:** nobody used VoiceOver, Voice Control or Switch Control by hand. Most findings are confirmed in source
only. Each issue says what was and was not verified.

## Readiness per App Store label

| Label | Ready? | What blocks it |
|---|---|---|
| VoiceOver | No | 4 blockers; results and errors are never announced; merged elements swallow buttons and text |
| Voice Control | No | About 60 controls whose spoken name does not contain the visible text; no `accessibilityInputLabels` |
| Larger Text | No | Grids and rows that never reflow; truncated essential text; gate screens that do not scroll |
| Sufficient Contrast | No | 168 measured "Contrast failed" items; brand green fails as text and as a button fill |
| Dark Interface | No | Brand blue and error red are not adaptive; adaptive text on fixed light backgrounds |
| Differentiate Without Color | No | Recruiting status and Personal Fit are colour-only |
| Reduced Motion | Close | Only short fades and slides are ungated |
| Captions / Audio Descriptions | n/a | No first-party media |

## Issues

| # | Severity | Issue | Verified |
|---|---|---|---|
| 1 | Blocker | [VoiceOver reads "Interaction content" instead of the message](issues/01-interaction-content.md) | Source + simulator |
| 2 | Blocker | [Timeline tasks cannot be read or completed with VoiceOver](issues/02-timeline-phase-card.md) | Source |
| 3 | Blocker | [Performance export share sheet dismisses itself after 0.5 s (looks broken for everyone)](issues/03-performance-export.md) | Source; not run |
| 4 | Blocker | [Document viewer hides Close and all controls after 3 s on videos](issues/04-document-viewer.md) | Source |
| 5 | High | [Results and errors are never announced; success messages vanish in 2–3 s](issues/05-status-messages.md) | Source |
| 6 | High | [Merged elements swallow buttons and drop visible information](issues/06-combined-elements.md) | Source; partly simulator |
| 7 | High | [Colour contrast below WCAG AA in light and dark mode](issues/07-contrast.md) | Computed + simulator |
| 8 | High | [Meaning conveyed by colour alone](issues/08-color-only.md) | Source |
| 9 | High | [Layouts that truncate, clip or cannot scroll at accessibility text sizes](issues/09-larger-text.md) | Source + simulator |
| 10 | High | [Hit targets under 44 pt; full-width buttons where only the word is tappable](issues/10-hit-targets.md) | Source + simulator |
| 11 | High | [Unnamed or misnamed controls and form fields; state not exposed](issues/11-names-and-forms.md) | Source |
| 12 | Medium | [Spoken names that do not contain the visible text](issues/12-voice-control.md) | Source |
| 13 | Medium | [Analytics charts lack Audio Graphs and per-point access](issues/13-charts.md) | Source |
| 14 | Low | [Reduce Motion, raw values, noise, unconfirmed discard, dead code](issues/14-polish.md) | Source |

One further High finding is privacy-sensitive and unverified on device. This repository is public, so it was reported
to the maintainer directly and is not in these files.

## Suggested order

1. The four blockers. The interaction-content fix is a one-line deletion; the performance export looks broken for
   every user and should be reproduced first.
2. The three shared components that fix many screens at once: `ToastModifier` (announce), `SaveStatusView`
   (announce), `FormFieldWrapper` (stop merging the control).
3. Colour tokens in `AppColors.swift`, decided together with the web app (recruiting-compass-web#1083).
4. The text-only tappable bars and the gate screens that do not scroll — both sit on first-run paths.
5. Everything else, area by area.

## Corrections made after checking on the simulator

- **Schools list and Coaches list cards are fine.** The static review flagged both for nesting buttons inside a
  tappable card (`areas/schools.md`, `areas/coaches.md`). The accessibility tree shows one button with a full composed
  label plus separate Delete / Add to favorites / Email coach buttons. Those two findings are withdrawn.
- **`FormFieldWrapper` is partly confirmed.** Each field is exposed as a generic element named e.g. "School Name,
  required" with the placeholder as its value, and an unlabelled text field beneath it. It is not exposed as a text
  field; whether activating it starts editing is still unverified.
- **Interaction content is confirmed** on the simulator, as are the dark-mode contrast failures on the login, forgot-password
  and signup Back buttons and on unread notifications.

## Also change

- `CLAUDE.md` says "Accessibility (WCAG AA Compliant)". Reword it as a goal until the blockers are closed.
- `CLAUDE.md` says "Form fields grouped with `.accessibilityElement(children: .combine)`". That rule is the source of
  the `FormFieldWrapper` problem; restrict it to read-only rows.
- Once the blockers and the contrast tokens are fixed, turn `AccessibilityAuditTests` into a gate for the
  logged-out screens (it needs no backend).

## What the app does well

Worth protecting while fixing the above: the Add School and Add Coach flows announce search results, selection and
errors; `AsyncButton` handles loading state, disabled state and hit size correctly; status badges almost always carry
text as well as colour; destructive actions confirm first; the invisible captcha needs no puzzle;
`PerformanceChartView` and `InteractionTrendsChart` have real Audio Graphs; toolbar icon buttons are labelled and
44 pt; Reduce Motion is honoured for the large transitions. Each area report ends with its own "Done well" list.
