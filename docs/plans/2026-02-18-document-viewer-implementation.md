# Document Viewer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Implement a fullscreen, distraction-free Document Viewer modal for quick preview and sharing. Minimal UI (close, share, download) with video/image/PDF preview support.

**Architecture:** New `Features/Documents/` subfeature: `DocumentViewer/` (View, ViewModel, Components). Reuses existing `Document` model, `DocumentPreviewView` components. Presented as fullscreen modal from Documents List. AVKit for video, PDFKit for PDF, SwiftUI zoomable image.

**Tech Stack:** SwiftUI, AVKit, PDFKit, UIActivityViewController (share sheet), URLSession (download)

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase6_DocumentViewer.md`  
**Web reference:** `recruiting-compass-web/pages/documents/view.vue` (iOS creates distinct simplified viewer)

---

## Prerequisites

- `Document` model exists (`Features/Documents/Models/Document.swift`)
- `DocumentPreviewView` and subviews exist (`DocumentPreviewView.swift`: `VideoPreviewView`, `ImagePreviewView`, `PDFPreviewView`, `DownloadFallbackView`)
- `DocumentsManaging` protocol and `DocumentsServiceImpl` exist

---

## Task 1: DocumentViewerViewModel

**Files:**
- Create: `TheRecruitingCompass/Features/Documents/ViewModels/DocumentViewerViewModel.swift`

**Requirements:**
- `@Observable` @MainActor ViewModel
- State: `document`, `isLoading`, `error`, `isToolbarVisible`, `isShareSheetPresented`, `downloadProgress`
- Optional collection: `collection: DocumentCollection?`, `currentIndex`
- Methods: `loadDocument(id:)`, `shareDocument()`, `downloadDocument()`, `retryLoad()`, `nextDocument()`, `previousDocument()`
- Protocol-based DI: accept `DocumentsManaging` (for fetch by ID if needed)
- Support init with `Document` directly (passed from list) — no fetch if document provided

**DocumentCollection** (from spec):
```swift
struct DocumentCollection {
  let documents: [Document]
  let currentIndex: Int
  var currentDocument: Document { documents[currentIndex] }
  var hasNext: Bool { currentIndex < documents.count - 1 }
  var hasPrevious: Bool { currentIndex > 0 }
}
```

**Step 1–5:** Implement, run `make build`, commit.

---

## Task 2: DocumentViewerView (Fullscreen Modal Shell)

**Files:**
- Create: `TheRecruitingCompass/Features/Documents/Views/DocumentViewerView.swift`

**Requirements:**
- Fullscreen modal, black background
- Top toolbar (translucent): Close (left), Title (center), Share + Download (right)
- Content area: `DocumentPreviewView(document: viewModel.document)` when loaded
- Loading: `ProgressView` overlay on translucent black
- Error: error message + Retry button + Close
- Swipe-down gesture to dismiss (interactive, `offset` on drag)
- Tap content to toggle toolbar visibility
- `@Environment(\.dismiss)` for Close
- Present share sheet via `sheet(isPresented:)` with `ShareSheet` UIViewControllerRepresentable

**Step 1–5:** Implement, run `make build`, commit.

---

## Task 3: Share Sheet and Download

**Files:**
- Create: `TheRecruitingCompass/Features/Documents/Components/ShareSheet.swift` (UIActivityViewController wrapper)
- Modify: `DocumentViewerViewModel.swift` — implement `shareDocument()` (set URL for share), `downloadDocument()` (URLSession.download, progress, save to Files)

**Requirements:**
- `ShareSheet` representable: takes `URL` or `[Any]`, presents `UIActivityViewController`
- Download: use `URLSession.shared.download(from:)`, move to Documents directory or use share sheet for "Save to Files"
- Progress: `downloadProgress` 0...1, show in UI
- Success: brief success message or haptic
- Error: set `error`, show retry

**Step 1–5:** Implement, run `make build`, commit.

---

## Task 4: Wire Documents List to Document Viewer

**Files:**
- Modify: `TheRecruitingCompass/Features/Documents/Views/DocumentsListView.swift`
- Modify: `DocumentsListViewModel.swift` (add `documentToView: Document?`, `presentViewer(for:)`)

**Requirements:**
- Add `@State private var documentToView: Document?`
- Change document card/row tap: set `documentToView = doc` instead of (or in addition to) NavigationLink
- Add `.fullScreenCover(item: $documentToView)` presenting `DocumentViewerView(document: document)`
- Keep `NavigationLink` to `DocumentDetailView` for "View Details" if desired, or remove and use only viewer for tap
- **Per spec:** "User taps document card" → "System presents Document Viewer modally" — so tap opens viewer. Optionally add context menu "View Details" for DocumentDetailView.

**Step 1–5:** Implement, run `make build`, commit.

---

## Task 5: Toolbar Auto-Hide (Video) and Polish

**Files:**
- Modify: `DocumentViewerView.swift`, `DocumentViewerViewModel.swift`

**Requirements:**
- For video: toolbar auto-hides after 3 seconds of inactivity
- Use `Task.sleep` or Timer; cancel on tap/interaction
- Ensure Close remains accessible (e.g. tap anywhere shows toolbar)
- Toolbar: translucent black background (`.ultraThinMaterial` or `Color.black.opacity(0.8)`)

**Step 1–5:** Implement, run `make build`, commit.

---

## Task 6: Bottom Navigation (Collection – Optional)

**Files:**
- Modify: `DocumentViewerView.swift`, `DocumentViewerViewModel.swift`

**Requirements:**
- If `viewModel.collection != nil`, show bottom toolbar: Previous | "3 of 10" | Next
- Previous/Next disabled when first/last
- Swipe left/right on content to navigate (if collection)
- Skip for MVP if time-constrained; spec says "optional for MVP"

**Step 1–5:** Implement or defer. Run `make build`, commit.

---

## Execution Notes

1. Follow MVVM, `@Observable`, protocol-based DI per CLAUDE.md
2. Reuse `DocumentPreviewView`, `VideoPreviewView`, `ImagePreviewView`, `PDFPreviewView`, `DownloadFallbackView`
3. All buttons: 44pt minimum hit targets
4. Run `make build` after each task
5. Commit after each task: `feat(documents): add Document Viewer Task N`
