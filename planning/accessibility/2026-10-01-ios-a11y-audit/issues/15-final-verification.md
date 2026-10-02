## Purpose

The last step of the accessibility work: prove the fixes hold before the app claims anything. Do this after the other audit issues are closed. Until it passes, do not declare App Store Accessibility Nutrition Labels and do not describe the app as WCAG AA compliant.

The 2026-10-01 audit was a source review plus Xcode's automated audit. Nobody used VoiceOver, Voice Control or Switch Control by hand, and several screens were never reached. This issue closes both gaps.

## 1. Automated audit is clean

Run `TheRecruitingCompassUITests/E2E/AccessibilityAuditTests.swift` (commands in `planning/accessibility/2026-10-01-ios-a11y-audit/automated-audit.md`) in all three runs. Baseline on 2026-10-01 was 759 issues across 28 screens.

- [ ] Light: no "Contrast failed", "Hit area is too small", "Text clipped", "Element has no description" or "Label not human-readable" items
- [ ] Dark (`xcrun simctl ui <udid> appearance dark`): same
- [ ] Largest text (`A11Y_AUDIT_CONFIG=largest-text`): same, and the walk reaches every screen
- [ ] Remaining "Contrast nearly passed" and "Dynamic Type partially unsupported" items are each reviewed and either fixed or listed here with a reason

Extend the walk to what the first audit missed:

- [ ] Recruiting Timeline with an expanded phase (needs the local web API running)
- [ ] Documents list, document detail and the document viewer (seed at least one image and one video)
- [ ] Onboarding steps, sport gate, push-priming sheet
- [ ] Family management, invite-join and the birthday-confirm sheet
- [ ] Forced-update gate and Face ID lock
- [ ] Create/Edit Event, Add Interaction, Quick Communication, Offer detail and calculator, Performance add-metric and export
- [ ] One iPad run

## 2. Manual passes on a real device

Use the smallest supported iPhone. For each pass, complete these tasks end to end: sign up, sign in, reset password, add a school, add a coach, log an interaction and read it back, complete a timeline task, create an event, upload and open a document, log an offer, add a performance metric and export, edit the player profile, invite a family member, change notification settings, delete a deadline.

- [ ] **VoiceOver** — every task completes; every control has a unique, meaningful name; state (selected, expanded, disabled) is spoken; results and errors are announced; nothing important disappears before it can be read; the Headings rotor reaches each section; focus lands somewhere sensible after navigation, sheets and errors
- [ ] **VoiceOver on modal screens** — on the update gate, the Face ID lock and every sheet, focus stays inside the modal and cannot reach content behind it
- [ ] **Voice Control** — "Tap <visible text>" works for every control on those tasks without falling back to numbers
- [ ] **Switch Control** — every task completes; no control is reachable only by gesture
- [ ] **Larger Text** at the largest accessibility size — nothing essential is truncated or clipped; every screen scrolls; every primary button is reachable
- [ ] **Dark Interface** — all text and controls readable on every screen visited
- [ ] **Increase Contrast** — no regressions
- [ ] **Differentiate Without Color** / greyscale filter — status, fit, urgency and chart series are distinguishable
- [ ] **Reduce Motion** — no slides, sweeps or animated scrolls remain
- [ ] **Hit targets** — every control responds across its whole visible shape

## 3. Decide per label

Check each against Apple's published criteria for that label (the user can complete all common tasks with the feature on) and record the decision here.

- [ ] VoiceOver
- [ ] Voice Control
- [ ] Larger Text
- [ ] Sufficient Contrast
- [ ] Dark Interface
- [ ] Differentiate Without Color Alone
- [ ] Reduced Motion

Captions and Audio Descriptions do not apply (no first-party media).

## 4. Lock it in

- [ ] Make the logged-out audit test a CI gate (it needs no backend) and add the signed-in run to the E2E job once that job is healthy
- [ ] Close #207 (hollow chart accessibility tests) with tests that assert real behaviour
- [ ] Reword the `CLAUDE.md` accessibility section: state what was verified and when; restrict the `.combine` rule to read-only rows
- [ ] Write the results to `planning/accessibility/` (date, device, OS, what passed, what was waived and why)
- [ ] Declare the labels that passed in App Store Connect

## Done when

Sections 1 and 2 pass with no open exceptions, each label in section 3 has a recorded yes or no, and section 4 is complete.

Part of the iOS accessibility audit — tracking issue: TRACKING
