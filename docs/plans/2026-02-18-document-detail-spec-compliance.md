# Document Detail Spec Compliance & Implementation Plan

**Spec:** `iOS_SPEC_Phase6_DocumentDetail.md`  
**Date:** February 18, 2026  
**Status:** Implementation largely complete; minor gaps identified

---

## 1. Compliance Summary

The Document Detail feature is **substantially implemented** and meets the core success criteria. The following sections are fully implemented.

### Fully Implemented

| Spec Section | Implementation | Notes |
|--------------|----------------|-------|
| **Primary Flow** | Document load, header, metadata, preview, edit, save | ✅ |
| **Flow B: Share** | Share modal with "Shared With" (Remove) and "Add Schools" (checkboxes) | ✅ |
| **Flow C: Upload New Version** | File picker, type validation, upload, version increment, mark current | ✅ |
| **Flow D: Restore Version** | Confirmation dialog, mark current→archived, mark selected→current | ✅ |
| **Flow E: Delete** | Confirmation dialog, delete from Storage + database, dismiss | ✅ |
| **Document not found** | `ContentUnavailableView` with "Return to Documents" | ✅ |
| **Preview unavailable** | Placeholder + Download button for unsupported types | ✅ |
| **Video preview** | `VideoPlayer` (AVPlayer) with 16:9 aspect ratio | ✅ |
| **PDF preview** | `PDFKitRepresentable` with `PDFView` (autoScales, singlePageContinuous) | ✅ |
| **Image preview** | `AsyncImage` with scaledToFit | ⚠️ No zoom/pan |
| **Edit form** | Title, School picker, Description; validation 100/500 chars | ✅ |
| **Metadata grid** | Version, School, Uploaded, File Type (2x2 grid) | ✅ |
| **Version history** | Version number, "Current" badge, date, View link, Restore button | ✅ |
| **Delete from Storage** | `DocumentsServiceImpl.deleteDocument` removes file then record | ✅ |
| **API integration** | fetchDocument, updateDocument, fetchVersionHistory, share, revoke | ✅ |
| **Error handling** | Error banner, retry button, alerts for save/share/delete failures | ✅ |
| **Accessibility** | Labels on Edit, Share, Delete, version row; 44pt hit targets | ✅ |
| **Navigation** | `navigationDestination` from Documents list; Back button | ✅ |

---

## 2. Gaps Identified

### High Priority (Spec-Explicit)

| Gap | Spec Requirement | Current State | Effort |
|-----|------------------|---------------|--------|
| **Image zoom/pan** | "Full-size image with zoom/pan", "Pinch to zoom, drag to pan" | `AsyncImage` only; no zoom/pan | Medium |
| **Upload progress percentage** | "Progress bar below file name", "Percentage text: 45%" | `ProgressView` overlay; no percentage | Low |
| **Long title truncation** | "Truncate with ellipsis in header (2 lines max)" | Full title shown | Low |

### Medium Priority (UX Polish)

| Gap | Spec Requirement | Current State | Effort |
|-----|------------------|---------------|--------|
| **401 handling** | "Handle 401 error (redirect to login)" | Generic error message | Low |
| **Video loading overlay** | "Spinner overlay on video player until buffered" | No overlay | Low |
| **Back button label** | "← Back to Documents" | "Back" | Trivial |

### Lower Priority (Optional / Edge Cases)

| Gap | Spec Requirement | Current State | Effort |
|-----|------------------|---------------|--------|
| **Skeleton loading** | Skeleton screens, shimmer, 300ms delay | `ProgressView` only | Medium |
| **Share modal max-height** | "Max-height scrollable (200pt)" for Add Schools | Full list | Trivial |
| **PDF progressive loading** | Load pages on-demand for large PDFs | Full load | High (optional) |
| **Save button color in Share modal** | Save (green) | Default confirmation tint | Trivial |

---

## 3. Implementation Plan

The following tasks complete spec compliance using established patterns from the codebase (MVVM, `@Observable`, protocol-based DI, CLAUDE.md).

---

### Task 1: Image Zoom/Pan (High)

**File:** `DocumentPreviewView.swift` – `ImagePreviewView`

**Approach:** Wrap image in a zoomable container using `MagnificationGesture` and `DragGesture`, following SwiftUI patterns.

```swift
// Add ZoomableImageView component
struct ZoomableImageView: View {
  let url: URL
  @State private var scale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  @State private var lastScale: CGFloat = 1.0

  var body: some View {
    AsyncImage(url: url) { phase in
      // ... phase handling
    }
    .scaleEffect(scale)
    .offset(offset)
    .gesture(
      MagnificationGesture()
        .onChanged { scale = lastScale * $0 }
        .onEnded { lastScale = scale; clampScale() }
    )
    .simultaneousGesture(
      DragGesture()
        .onChanged { offset = CGSize(width: lastOffset.width + $0.translation.width, ...) }
        .onEnded { lastOffset = offset }
    )
  }
}
```

**Tests:** Accessibility and layout tests; ensure pinch/pan work with VoiceOver.

---

### Task 2: Upload Progress with Percentage (High)

**Files:**
- `DocumentDetailViewModel.swift` – `uploadProgress` already exists; ensure it reflects real progress if possible
- `DocumentDetailView.swift` – `versionHistoryCard` upload overlay

**Approach:**
- If Supabase storage upload supports progress callbacks, wire `uploadProgress` to them.
- Otherwise, show indeterminate progress with a clear "Uploading..." label and optional phase text (e.g. "Preparing…", "Uploading…").
- Add `ProgressView(value: viewModel.uploadProgress)` and `Text("\(Int(viewModel.uploadProgress * 100))%")` when progress is determinate.

**Reference:** `DocumentDetailView` lines 314–318 (upload overlay).

---

### Task 3: Long Title Truncation (High)

**File:** `DocumentDetailView.swift` – `documentHeaderCard`

**Change:**
```swift
Text(document.title)
  .font(.title2)
  .fontWeight(.bold)
  .lineLimit(2)
  .truncationMode(.tail)
```

---

### Task 4: 401 Handling (Medium)

**Files:**
- `DocumentDetailViewModel.swift` – `loadDocument()`, `saveEdit()`, etc.
- `Core/Services/AuthManager.swift` – sign-out API
- Shared error-handling pattern (if any)

**Approach:**
- Add `isUnauthorized(_ error: Error) -> Bool` (e.g. check for 401 or Supabase auth error codes).
- On 401, call `authManager.signOut()` and set `error = "Your session has expired. Please sign in again."` (or similar).
- Optionally set a flag like `shouldDismissToLogin` that the view uses to dismiss and show login.

**Pattern:** Match how other features (e.g. Event Detail, School Detail) handle auth errors.

---

### Task 5: Video Loading Overlay (Medium)

**File:** `DocumentPreviewView.swift` – `VideoPreviewView`

**Approach:**
- Add `@State private var isBuffering = true`.
- Use `AVPlayer` + `AVPlayerViewController` (or `VideoPlayer` with `onStateChanged` if available) to detect when playback is ready.
- Show `ProgressView` overlay until buffering completes; hide when playable.

**Note:** SwiftUI `VideoPlayer` has limited state callbacks. Consider `AVPlayerLayer` + `KVO` on `status`/`timeControlStatus` via `UIViewRepresentable` if overlay timing matters.

---

### Task 6: Back Button Label (Trivial)

**File:** `DocumentDetailView.swift` – `toolbarContent`

**Change:**
```swift
Button("Back to Documents") { dismiss() }
  .accessibilityLabel("Back to Documents")
```

---

### Task 7: Share Modal – Save Button Tint (Trivial)

**File:** `DocumentShareSheet.swift` – Save button

**Change:**
```swift
Button("Save") { Task { await viewModel.saveShare() } }
  .disabled(viewModel.selectedSchoolIds.isEmpty)
  .tint(Color.primaryGreen)  // If primaryGreen exists in theme
```

---

### Task 8: Share Modal – Add Schools Max Height (Optional)

**File:** `DocumentShareSheet.swift` – `addSchoolsSection`

**Change:**
```swift
Section("Add Schools") {
  ScrollView {
    LazyVStack { ... }
  }
  .frame(maxHeight: 200)
}
```

Use `List` with `.frame(maxHeight:)` or `ScrollView` + `LazyVStack` depending on current layout.

---

## 4. Testing Checklist (from Spec)

Use spec Section 9 as the regression checklist. After implementing the above:

- [ ] Image preview supports zoom and pan gestures
- [ ] Upload progress shows percentage when available
- [ ] Very long title displays correctly (truncated)
- [ ] Handle 401 error (redirect or clear session)
- [ ] VoiceOver reads all elements correctly

---

## 5. Out of Scope / Deferred

- **Skeleton loading with shimmer** – Spec enhancement; current `ProgressView` loading is acceptable.
- **PDF progressive loading** – High effort; document as known limitation.
- **Version "View" in-app preview** – Current `Link` to URL is acceptable per spec.

---

## 6. Recommended Order

1. **Task 3** – Title truncation (trivial, low risk)
2. **Task 6** – Back button label (trivial)
3. **Task 7** – Share Save tint (trivial)
4. **Task 2** – Upload progress percentage (low)
5. **Task 4** – 401 handling (low)
6. **Task 5** – Video loading overlay (low–medium)
7. **Task 1** – Image zoom/pan (medium)
8. **Task 8** – Share modal max height (optional)

---

## 7. Sign-Off

**Spec coverage:** ~90% implemented; remaining gaps are UX polish and one medium-effort feature (image zoom/pan).  
**Ready for implementation:** Yes.  
**Estimated effort:** 1–2 days for high/medium priority items.
