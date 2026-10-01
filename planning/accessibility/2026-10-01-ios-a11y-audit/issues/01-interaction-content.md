## Problem

On the interaction detail screen, VoiceOver reads the literal words "Interaction content" instead of the message body. The body is not spoken anywhere else in the Interactions tab (the list card's label omits it), so a VoiceOver user cannot read what a logged interaction says.

`Features/Interactions/Views/InteractionDetailView.swift:190-194`

```swift
Text(content)
  .font(.body)
  .textSelection(.enabled)
  .accessibilityLabel(String(localized: "Interaction content"))
```

An explicit `accessibilityLabel` on a `Text` replaces the text.

## Fix

Delete the `.accessibilityLabel`. The "Content" heading directly above already has the `.isHeader` trait and gives context.

## Done when

- A unit test asserts the spoken text for the content row (existing pattern: expose the computed label, assert on it).
- VoiceOver reads the message body.

## Evidence

Confirmed in source **and on the simulator**: the accessibility tree for the interaction detail screen exposes the body as a static text whose label is `Interaction content`. Severity: **Blocker** — information unavailable to VoiceOver users on a main flow.

Part of the iOS accessibility audit — tracking issue: TRACKING
