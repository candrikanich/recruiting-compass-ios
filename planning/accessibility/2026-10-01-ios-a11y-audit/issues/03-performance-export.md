## Problem

The Performance export share sheet dismisses itself half a second after it appears, so the share button inside it cannot be reached. From the code this looks broken for **every** user, not only assistive-technology users.

`Features/Performance/Components/ShareSheetView.swift:10-18`, presented from `Features/Performance/Components/ExportFormatSheet.swift:66-68`:

```swift
ShareLink(item: url) {
  Label("Share \(filename)", systemImage: "square.and.arrow.up")
}
.onAppear {
  Task {
    try? await Task.sleep(for: .seconds(0.5))
    dismiss()
  }
}
```

The sheet's only content is a `ShareLink` the user must tap; the timer closes the sheet first. For VoiceOver, Switch Control and Voice Control users it is unreachable outright (WCAG 2.2.1 Timing Adjustable).

## Fix

Drop the intermediate sheet and timer. Either make the "Export CSV/PDF" button in `ExportFormatSheet` a `ShareLink(item:)` (write the temp file when the format is chosen), or present the existing `ActivityShareSheet` from `Shared/Components` the way Analytics does.

## Done when

- Exporting performance metrics as CSV and as PDF opens the system share sheet, which stays open until the user acts.
- Works with VoiceOver on.

## Evidence

Confirmed by reading the source. **Not run** — reproduce on a device first (More → Performance → export). Severity: **Blocker** if it reproduces.

Part of the iOS accessibility audit — tracking issue: TRACKING
