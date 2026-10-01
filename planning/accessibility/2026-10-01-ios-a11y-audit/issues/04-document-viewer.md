## Problem

When a video document opens in the full-screen viewer, every control — Close, Share, Download, previous/next — is removed from the screen after 3 seconds. The only way to bring them back is a tap gesture on the background that has no accessibility element, trait or action. A VoiceOver or Switch Control user may be unable to leave the viewer.

- `Features/Documents/ViewModels/DocumentViewerViewModel.swift:134-141` — `scheduleToolbarAutoHide()` sets `isToolbarVisible = false` after `Task.sleep(for: .seconds(3))`; not gated on VoiceOver or Switch Control running.
- `Features/Documents/Views/DocumentViewerView.swift:72-80` — `if viewModel.isToolbarVisible { topToolbar }` removes the controls from the hierarchy.
- `:107-127` — the toggle is `.onTapGesture` on the root `ZStack`. The view is a `fullScreenCover` with no `.accessibilityAction(.escape)`; the other exit is a 150 pt drag-down.

Related defects in the same area:

- `DocumentViewerView.swift:174-232` — `topToolbar` is `VStack { HStack…; Spacer() }.background(Color.black.opacity(0.8))`. The `Spacer` makes the stack full height, so the 80 % black background covers the whole document whenever the toolbar is visible.
- `:301-305` — `Button("Retry").buttonStyle(.borderedProminent).tint(.white)` is probably a white label on a white fill.
- `Features/Documents/Components/Preview/ImagePreviewView.swift:44-85` — the image has no accessibility label, and zoom is pinch/double-tap only.

## Fix

- Do not auto-hide while VoiceOver or Switch Control is running; keep Close permanently in the tree (fade only Share/Download/paging).
- Add `.accessibilityAction(.escape) { dismiss() }` to the cover root and `.accessibilityAction(named: "Show controls")` for the toggle.
- Move the scrim background onto the toolbar `HStack` only; give Retry a dark label.
- Label the image with the document title and add `.accessibilityZoomAction` or +/- buttons.

## Done when

With VoiceOver on, a user can open a video document, wait 10 seconds, and still close the viewer.

## Evidence

Confirmed by reading the source. Not confirmed on device — the seeded demo account has no documents. Whether VoiceOver's synthesized tap on the embedded player reaches the SwiftUI gesture is the unverified part. Severity: **Blocker** if it does not.

Part of the iOS accessibility audit — tracking issue: TRACKING
