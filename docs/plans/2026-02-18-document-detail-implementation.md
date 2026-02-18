# Document Detail Implementation Plan

**Spec:** [iOS_SPEC_Phase6_DocumentDetail.md](../../recruiting-compass-web/planning/iOS_SPEC_Phase6_DocumentDetail.md)
**Created:** 2026-02-18
**Project:** recruiting-compass-ios
**Web Reference:** recruiting-compass-web/pages/documents/[id].vue

---

## Overview

Implement the full Document Detail page, replacing `DocumentDetailPlaceholderView` with a feature-complete view. Web implementation exists at `recruiting-compass-web/pages/documents/[id].vue`. Follow MVVM, use `EventDetailViewModel` and `SchoolDetail` as patterns.

---

## Tasks (Subagent-Driven Development Order)

### Task 1: Service Layer & Models Extension

**Goal:** Extend DocumentsManaging and add missing models.

- Add to `DocumentsManaging` protocol:
  - `fetchDocument(id: String) async throws -> Document`
  - `updateDocument(id: String, title: String?, description: String?, schoolId: String?) async throws -> Document`
  - `fetchVersionHistory(documentId: String, document: Document) async throws -> [DocumentVersion]`
  - `shareDocument(documentId: String, schoolId: String) async throws`
  - `revokeShare(documentId: String, schoolId: String) async throws`
  - `deleteDocument(id: String, userId: String) async throws` (already exists; ensure Storage deletion)
- Add `DocumentVersion` struct (id, version, fileUrl, isCurrent, createdAt, displayDate)
- Add `isVideo`, `isImage`, `isPDF`, `canPreview` computed to `Document` if missing
- Implement in `DocumentsServiceImpl`

**Reference:** Spec Sections 3, 4; Web useDocumentsConsolidated composable.

---

### Task 2: DocumentDetailViewModel

**Goal:** @Observable ViewModel with full state and actions.

- State: document, versions, schools, isLoading, error, isNotFound, shouldDismiss
- Edit state: showEditSheet, editTitle, editDescription, editSchoolId, isSaving
- Share state: showShareModal, selectedSchoolIds
- Version state: isUploadingNewVersion, uploadProgress
- Delete state: showDeleteConfirmation, isDeleting
- Actions: loadDocument(), saveEdit(), presentShareModal(), saveShare(), removeShare(), deleteDocument(), fetchVersions(), restoreVersion(), uploadNewVersion(file:)
- Dependencies: DocumentsManaging, SchoolsManaging (for dropdown), AuthManaging
- Inject documentId: String

**Reference:** EventDetailViewModel pattern; Spec Sections 4, 5.

---

### Task 3: DocumentDetailView – Layout & Header

**Goal:** Main view structure and document header card.

- NavigationView with "← Back to Documents" (or standard back)
- ScrollView containing:
  - Document Header Card: type badge, title, description, action buttons row (Edit, Share, Delete)
  - Metadata Grid: Version, School, Uploaded, File Type (4 columns, 2 rows on iPhone)
- Wire to DocumentDetailViewModel
- Loading skeleton, error banner, "Document not found" empty state
- Replace DocumentDetailPlaceholderView in navigation

**Reference:** Spec Section 6; Web [id].vue layout; EventDetailView structure.

---

### Task 4: Document Preview Components

**Goal:** Video, image, PDF, and fallback preview.

- Video: Use AVPlayerViewController (UIKit) via UIViewControllerRepresentable or AVPlayer + video player view
- Image: AsyncImage or custom with zoom/pan (optional: simple full-width first)
- PDF: PDFKit PDFView in SwiftUI via UIViewRepresentable
- Other: "Preview unavailable" + Download button (opens URL in Safari or share sheet)
- Handle loading and error states per spec

**Reference:** Spec Section 6; AVKit, PDFKit; Web VideoPlayer, iframe for PDF.

---

### Task 5: Edit Form, Share Modal, Version History

**Goal:** Edit sheet, share modal, version history list.

- Edit Form (sheet): Title (required, max 100), School dropdown, Description (3 rows, max 500). Save/Cancel.
- Share Modal: Currently shared schools with Remove; available schools with checkboxes; Save/Close.
- Version History: List versions (vN, date, Current badge); View (open preview), Restore (with confirmation); "+ Upload New Version" (document picker)
- Restore confirmation: "Restore this version? The current version will be marked as archived."
- Delete confirmation: "Are you sure you want to delete this document? This action cannot be undone."

**Reference:** Spec Section 6; Web [id].vue edit/share/version sections.

---

### Task 6: Integration & Polish

**Goal:** Wire navigation, ensure Documents list navigates to DocumentDetailView.

- Update DocumentsListView navigation: NavigationLink from DocumentCard to DocumentDetailView(documentId:)
- Ensure DocumentsListViewModel/View passes documentId correctly
- Handle shouldDismiss → pop navigation after delete
- Verify refresh/error handling
- Apply AppColors, AppGradients, semantic fonts per project guidelines

**Reference:** Spec Section 2 flows; CLAUDE.md.

---

## Testing Requirements (Separate Agents)

- **Unit:** DocumentDetailViewModel, service methods, model computed properties
- **E2E:** Load document, edit, share, version history, delete flows
- **Accessibility:** VoiceOver labels, 44pt touch targets, Dynamic Type

---

## Dependencies

- Supabase (documents table, Storage)
- AVKit, PDFKit, UIKit (document picker)
- Existing: Document, DocumentType, DocumentsManaging, SchoolsManaging, AuthManaging
