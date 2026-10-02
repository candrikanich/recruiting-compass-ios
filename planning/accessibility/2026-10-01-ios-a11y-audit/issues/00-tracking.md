Tracking issue for the iOS accessibility audit of 2026-10-01 (commit `d775d198`).

**Verdict:** the app is not ready to declare any App Store Accessibility Nutrition Label, and "WCAG AA compliant" is not currently true. Basic labelling is good, but there are four blockers and a handful of shared root causes behind most of the rest.

Full report: `planning/accessibility/2026-10-01-ios-a11y-audit/README.md` (branch `worktree-a11y-audit`).

## Issues

CHECKLIST

Related: #207 (hollow chart accessibility tests). Web has the same palette and contrast failures — see recruiting-compass-web#1083; decide the colour tokens once for both platforms.

## Readiness per App Store label

| Label | Ready? | What blocks it |
|---|---|---|
| VoiceOver | No | 4 blockers; results and errors are never announced; merged elements swallow buttons and text |
| Voice Control | No | About 60 controls whose spoken name does not contain the visible text |
| Larger Text | No | Grids and rows that never reflow; truncated essential text; gate screens that do not scroll |
| Sufficient Contrast | No | 168 measured "Contrast failed" items; brand green fails as text and as a button fill |
| Dark Interface | No | Brand blue and error red are not adaptive; adaptive text on fixed light backgrounds |
| Differentiate Without Color | No | Recruiting status and Personal Fit are colour-only |
| Reduced Motion | Close | Only short fades and slides are ungated |

## Suggested order

1. The four blockers. The interaction-content fix is a one-line deletion; the performance export looks broken for every user and should be reproduced first.
2. The three shared components that fix many screens at once: `ToastModifier` and `SaveStatusView` (announce), `FormFieldWrapper` (stop merging the control).
3. Colour tokens in `AppColors.swift`, decided together with web.
4. The text-only tappable bars and the gate screens that do not scroll — both sit on first-run paths.
5. Everything else, area by area.
6. The final verification issue, last.

## How the audit was done

Source review of every view file (about 190 raw findings from six area reviews), contrast ratios computed from the colour tokens, and Xcode's automated audit on the simulator in light, dark and largest-text runs (759 issues across 28 screens). The top findings were re-read in source and checked against the captured accessibility trees. **Nobody used VoiceOver, Voice Control or Switch Control by hand**; each issue says what was and was not verified.
