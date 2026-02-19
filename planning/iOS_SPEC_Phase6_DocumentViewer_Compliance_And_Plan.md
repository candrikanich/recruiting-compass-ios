# iOS Spec Phase 6 – Document Viewer: Compliance Assessment & Implementation Plan

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase6_DocumentViewer.md`  
**Assessment Date:** February 18, 2026  
**Implementation Date:** February 18, 2026  
**Branch:** Current (vs main)  
**Status:** ✅ Implemented

---

## Executive Summary

Most of the Document Viewer spec is implemented. The viewer opens as a fullscreen modal from Documents List, supports video/image/PDF/fallback previews, share, download, collection navigation, and core accessibility. Several spec items are missing or differ from the spec. This plan lists gaps and proposed fixes.

---

## 1. Compliance Checklist

### ✅ Fully Implemented

| Spec Section | Requirement | Implementation |
|--------------|-------------|----------------|
| 1 Overview | Fullscreen modal viewer | `DocumentViewerView` fullscreen modal |
| 1 | Video, image, PDF previews | `DocumentPreviewView` → `VideoPreviewView`, `ImagePreviewView`, `PDFPreviewView` |
| 1 | Share via iOS share sheet | `ShareSheet` (UIActivityViewController) |
| 1 | Download to device | `DocumentViewerViewModel.downloadDocument()` |
| 1 | Close / swipe down dismiss | Close button + swipe down (150pt threshold) |
| 1 | Collection navigation | Bottom toolbar with prev/next + page indicator |
| 1 | Toolbar toggle on tap | `onTapGesture` toggles `isToolbarVisible` |
| 2 Flow A | Primary flow | Document card tap → fullscreen cover → preview → close |
| 2 Flow B | Share flow | Share button → UIActivityViewController |
| 2 Flow C | Download flow | Download → URLSession → save to Documents → present share sheet |
| 2 Flow D | Collection navigation | Prev/Next buttons |
| 2 Flow E | Toolbar auto-hide (video) | 3s timer after tap; `scheduleToolbarAutoHide` / `cancelToolbarAutoHide` |
| 3 Data | Document model | `Document`, `DocumentCollection` match spec |
| 3 | DocumentCollection | `hasNext`, `hasPrevious`, `nextDocument()`, `previousDocument()` |
| 4 API | Fetch by ID | `DocumentsManaging.fetchDocument(id:)` |
| 4 | Download from file_url | `URLSession.shared.download(from: url)` |
| 5 State | Page-level state | document, isLoading, error, isToolbarVisible, isShareSheetPresented, downloadProgress, collection, currentIndex |
| 6 Layout | Top toolbar | Close (xmark.circle.fill), title, share, download |
| 6 | Bottom toolbar (collection) | chevron.left, page indicator, chevron.right |
| 6 | Toolbar 44×44pt | `DocumentViewerLayout.toolbarButtonMinSize = 44` |
| 6 | Overlay 0.8 opacity | `Color.black.opacity(DocumentViewerLayout.overlayOpacity)` |
| 6 | Video: AVPlayerViewController | `VideoPlayerViewControllerRepresentable` wraps AVPlayerViewController |
| 6 | Image: pinch/pan/double-tap | `ZoomableImageView` with MagnificationGesture, DragGesture, onTapGesture(count: 2) |
| 6 | PDF: PDFView | `PDFKitRepresentable` uses PDFView |
| 6 | Other: Download fallback | `DownloadFallbackView` |
| 6 | Tap → toggle toolbar | Implemented |
| 6 | Swipe down → dismiss | Implemented |
| 6 Loading | Spinner overlay | White spinner on translucent black |
| 6 Error | Error overlay | Retry + Close, decorative icon hidden |
| 6 Accessibility | VoiceOver labels | Close, share, download, prev, next, page indicator, retry, close |
| 6 Accessibility | 44pt targets | All buttons |
| 6 Accessibility | Decorative icon hidden | `exclamationmark.triangle` `.accessibilityHidden(true)` |
| 7 | SwiftUI, AVKit, PDFKit, UIKit | Used |
| 8 Error | "Unable to load document" | Implemented |
| 8 Error | Retry, Close | Implemented |

---

## 2. Gaps & Discrepancies

### 2.1 Missing: Download Progress UI

- **Spec 6:** “Linear progress bar below download button” with percentage, e.g. “45%”.
- **Current:** `downloadProgress` is updated in the ViewModel but not shown in the UI.
- **Impact:** User has no feedback during download.

### 2.2 Missing: Swipe Left/Right for Collection Navigation

- **Spec 6:** “Swipe Left/Right (if collection): Action: Navigate to next/previous document.”
- **Current:** Navigation only via prev/next buttons.
- **Impact:** Less discoverable; no gesture parity with Photos app.

### 2.3 Error Message Wording

- **Spec 8:** Download failure → “Download failed. Check your connection.”
- **Current:** `"Download failed. \(error.localizedDescription)"` (technical).
- **Spec 2:** Document not found → “Document not found”.
- **Current:** ContentUnavailableView “No document” / “Unable to load document”.
- **Impact:** UX and consistency with spec.

### 2.4 Image Zoom Range

- **Spec 6:** Image zoom 1× to 5×.
- **Current:** `ZoomableImageView` maxScale = 4.0.
- **Impact:** Minor; 4× is close but not spec-compliant.

### 2.5 Download Fallback Button Copy

- **Spec 6:** “Download to view” (blue filled).
- **Current:** “Download [title]” (blue filled).
- **Impact:** Minor; wording differs from spec.

### 2.6 Status Bar Hiding

- **Spec Appendix:** `.statusBar(hidden: !isToolbarVisible)` for immersive video.
- **Current:** No `statusBar` modifier.
- **Impact:** Status bar stays visible when toolbar auto-hides; less immersive.

### 2.7 Fullscreen Preview Styling

- **Spec 6:** Content area “full height, edge-to-edge”.
- **Current:** `VideoPreviewView` uses `aspectRatio(16/9)` and `cornerRadius(8)`; `ImagePreviewView`/`PDFPreviewView` use `cornerRadius(8)`. These are shared with Document Detail (non-fullscreen).
- **Impact:** Fullscreen viewer doesn’t fully match “edge-to-edge” spec.

### 2.8 Optional / Lower Priority (Spec 8)

- **Spec 8:** “Low storage” alert before download.
- **Spec 8:** Offline mode (disable download, allow cached viewing).
- **Spec 8:** Network-specific errors: timeout, no internet, server error.
- **Current:** Generic error handling.
- **Impact:** Nice-to-have; can be deferred.

---

## 3. Implementation Plan

### 3.1 Priority 1 – Quick Wins

| Task | File(s) | Action |
|------|---------|--------|
| **A. Error message wording** | `DocumentViewerViewModel.swift` | Use “Download failed. Check your connection.” for download errors instead of `error.localizedDescription`. |
| **B. “Document not found” empty state** | `DocumentViewerView.swift` | For error overlay or empty document state, use message “Document not found” when appropriate. |
| **C. Image zoom 1×–5×** | `DocumentPreviewView.swift` | Change `ZoomableImageView` `maxScale` from 4.0 to 5.0. |
| **D. Download fallback button** | `DocumentPreviewView.swift` | Change `DownloadFallbackView` button label to “Download to view”. |

### 3.2 Priority 2 – Spec-Critical Gaps

| Task | File(s) | Action |
|------|---------|--------|
| **E. Download progress UI** | `DocumentViewerView.swift`, `DocumentViewerViewModel.swift` | Show a linear progress bar (and optionally %) near the download button while `downloadProgress` &lt; 1. `URLSession.download` does not report progress directly; either: (a) show indeterminate spinner during download, or (b) use `URLSessionDownloadDelegate` with `urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)` to update `downloadProgress`. Prefer (b) for spec compliance. |
| **F. Swipe left/right for collection** | `DocumentViewerView.swift` | Add `DragGesture` (horizontal) to content area when `viewModel.collection != nil`: on swipe left and `hasNext` → `nextDocument()`; on swipe right and `hasPrevious` → `previousDocument()`. Ensure it does not conflict with vertical swipe-to-dismiss; use `simultaneousGesture` or separate gesture handling. |
| **G. Status bar hiding** | `DocumentViewerView.swift` | Add `.statusBarHidden(!viewModel.isToolbarVisible)` so the status bar hides when the toolbar auto-hides. |

### 3.3 Priority 3 – Polish

| Task | File(s) | Action |
|------|---------|--------|
| **H. Fullscreen preview layout** | `DocumentPreviewView.swift` or new viewer-specific wrapper | Provide a fullscreen-friendly variant that: (1) removes `cornerRadius(8)` and (2) lets video use full area instead of fixed 16/9. Options: add an `isFullscreen: Bool` to `DocumentPreviewView` and adjust layout, or create `DocumentViewerContentViewController` that embeds `DocumentPreviewView` with fullscreen-specific modifiers. |
| **I. Network error specificity** | `DocumentViewerViewModel.swift` | Map `URLError` (e.g. `networkConnectionLost`, `timedOut`) to “No internet connection…” / “Connection timed out” per spec. |

### 3.4 Deferred (Optional)

- Low storage alert before download.
- Offline mode detection.
- 10s load timeout.
- Large-file edge cases (1GB+ video, 500+ page PDF).

---

## 4. Recommended Implementation Order

1. **A, B, C, D** – Error copy, zoom range, fallback button (low risk, fast).
2. **E** – Download progress (requires ViewModel + View changes).
3. **F** – Swipe left/right for collection (gesture handling).
4. **G** – Status bar hiding.
5. **H, I** – Fullscreen layout and network error wording.

---

## 5. Patterns to Follow

Per `CLAUDE.md` and `docs/CODE_PATTERNS.md`:

- MVVM: ViewModel owns state; View renders and calls methods.
- `@Observable` + `@MainActor` for ViewModels.
- Protocol-based DI for services (e.g. `DocumentsManaging`).
- Accessibility: `.accessibilityLabel()`, 44pt targets, `.accessibilityHidden(true)` for decorative elements.
- Test files mirror source (e.g. `DocumentViewerViewModelTests`, `DocumentViewerAccessibilityTests`).

---

## 6. Verification

After implementation:

1. Run unit tests: `make test-unit` or `xcodebuild test -scheme TheRecruitingCompass`.
2. Manual checks:
   - Open document from list → fullscreen.
   - Video: toolbar auto-hides, status bar hides when toolbar hides.
   - Image: pinch 1×–5×, double-tap.
   - PDF: scroll/zoom.
   - Share, download, progress during download.
   - Collection: prev/next buttons and swipe left/right.
   - Error overlay and retry.
   - VoiceOver on all controls.
3. Reference: `TheRecruitingCompassTests/Features/Documents/Accessibility/DocumentViewerAccessibilityTests.swift`.
