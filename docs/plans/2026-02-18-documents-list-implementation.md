# Documents List Implementation Plan

> **For Claude:** Use subagent-driven development to implement this plan task-by-task. Each task: implementer → spec reviewer → code quality reviewer before moving on.

**Goal:** Implement the Phase 6 Documents List feature for iOS, mirroring the Nuxt web app at `/documents` with document management, upload, filter, sort, and grid/list views.

**Architecture:** MVVM with `@Observable` ViewModels, protocol-based Services (DocumentsManaging), Supabase for data and storage. Follow existing Features structure (Events, Schools). Use `UIDocumentPickerViewController` for file selection, Supabase Storage for uploads.

**Tech Stack:** SwiftUI, @Observable, Supabase iOS SDK, UIDocumentPickerViewController, AVFoundation (video thumbnails), PDFKit (PDF thumbnails).

---

## Reference

- **Spec:** `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/planning/iOS_SPEC_Phase6_DocumentsList.md`
- **Web implementation:** `recruiting-compass-web/pages/documents/index.vue`, `composables/useDocumentsConsolidated.ts`
- **Similar iOS features:** `Features/Events/`, `Features/Schools/`

---

## Task 1: Models (Document, DocumentType, DocumentStatistics)

**Files:**
- Create: `TheRecruitingCompass/Features/Documents/Models/Document.swift`
- Create: `TheRecruitingCompass/Features/Documents/Models/DocumentType.swift`
- Create: `TheRecruitingCompass/Features/Documents/Models/DocumentStatistics.swift`

**Implementation:**
- `Document`: Codable, Identifiable with id, userId, type, title, description, fileUrl, fileType, version, schoolId, isCurrent, sharedWithSchools, uploadedBy, createdAt, updatedAt; computed `isShared`, `typeEmoji`, `displayDate` (use DateFormatter/ISO8601)
- `DocumentType`: enum with raw values (highlight_video, transcript, resume, rec_letter, questionnaire, stats_sheet), `label`, `allowedExtensions`
- `DocumentStatistics`: total, shared, mostCommonType, totalStorageMB (placeholder "Phase 5" for storage)
- Ensure JSON keys match Supabase schema (snake_case: user_id, file_url, etc.)

---

## Task 2: DocumentsManaging Protocol and DocumentsService

**Files:**
- Create: `TheRecruitingCompass/Features/Documents/Services/DocumentsManaging.swift`
- Create: `TheRecruitingCompass/Features/Documents/Services/DocumentsServiceImpl.swift`

**Protocol methods:**
- `func fetchDocuments(userId: String) async throws -> [Document]`
- `func uploadDocument(userId: String, file: Data, fileName: String, mimeType: String, type: DocumentType, title: String, description: String?, schoolId: String?, version: Int) async throws -> Document`
- `func deleteDocument(id: String, userId: String) async throws`

**Implementation:**
- Use SupabaseManager (from Core) for `.from("documents")` queries and `.storage.from("documents")` uploads
- Storage path: `{userId}/{type}/{timestamp}_{filename}`
- Delete: fetch document, remove from storage (parse path from file_url), then delete DB record
- Handle 401/403/500 per spec

---

## Task 3: DocumentsListViewModel (State, Fetch, Filter, Sort)

**Files:**
- Create: `TheRecruitingCompass/Features/Documents/ViewModels/DocumentsListViewModel.swift`

**State:** documents, schools, isLoading, error, isUploadFormPresented, uploadProgress; searchQuery, selectedTypes, selectedSchoolId, showSharedOnly; sortBy (SortOption), viewMode (ViewMode)

**Persistence:** UserDefaults for viewMode ("documentsViewMode"), sortBy ("documentsSortBy")

**Methods:**
- `loadDocuments()` async
- `loadSchools()` (delegate to schools service)
- `filteredDocuments` computed (search, type, school, shared filters)
- `sortedDocuments` computed (newest, oldest, name, type, shared)
- `statistics` computed (total, shared count, mostCommonType, storage placeholder)
- `deleteDocument(id:)` async
- `presentUploadForm()` / `dismissUploadForm()`

**Inject:** DocumentsManaging, SchoolsManaging (or equivalent), AuthManaging for userId

---

## Task 4: Upload Flow (ViewModel + Document Picker)

**Files:**
- Modify: `DocumentsListViewModel.swift`
- Create: `TheRecruitingCompass/Features/Documents/ViewModels/DocumentUploadViewModel.swift` (optional – or keep in list VM)

**Upload flow:**
- User selects file via UIDocumentPickerViewController (presented from view)
- Validate file extension against `DocumentType.allowedExtensions`
- Call service `uploadDocument` with progress (Supabase Storage supports progress)
- On success: append to documents, dismiss form
- On error: set error message

**Upload form state:** type, title, description, schoolId, version, selectedFileURL, selectedFileName

---

## Task 5: DocumentsListView (Layout, Header, Stats, Filter Bar)

**Files:**
- Create: `TheRecruitingCompass/Features/Documents/Views/DocumentsListView.swift`
- Create: `TheRecruitingCompass/Features/Documents/Components/StatisticsCardsRow.swift`
- Create: `TheRecruitingCompass/Features/Documents/Components/DocumentFilterBar.swift`

**Layout:**
- NavigationView with title "Documents", subtitle "{filteredCount} of {totalCount} total"
- Horizontal ScrollView of 4 stat cards (Total, Shared, Most Common Type, Total Storage)
- Filter bar: filter button, search field, sort picker
- Grid/List toggle buttons
- Content area (LazyVGrid or List)
- FAB: "+ Upload Document" bottom-right

---

## Task 6: Document Cards (Grid + List)

**Files:**
- Create: `TheRecruitingCompass/Features/Documents/Components/DocumentCardView.swift`
- Create: `TheRecruitingCompass/Features/Documents/Components/DocumentListViewRow.swift`

**Grid card:** thumbnail (16:9), type badge, title (2 lines max), metadata, shared badge; tap → navigate to detail
**List row:** thumbnail 80×60, title + metadata, shared badge; swipe delete
**Empty state:** icon, "No documents yet", subtitle, CTA button
**Loading:** skeleton or ProgressView

---

## Task 7: Upload Form Sheet

**Files:**
- Create: `TheRecruitingCompass/Features/Documents/Components/DocumentUploadSheet.swift`

**Form fields:** Type (picker), Title (required), School (optional), Version (optional), Description (optional), File (document picker button)
**Validation:** type, title, file required
**Progress bar** during upload
**Buttons:** Upload (disabled until valid), Cancel

---

## Task 8: Navigation and Wiring

**Files:**
- Modify: App routing / tab / dashboard to add Documents entry
- Create: `DocumentsListView` as root for Documents tab/screen

**Navigation:** Tap card → DocumentDetailView (stub or Phase 6 follow-up). For now, navigation can go to a placeholder.

---

## Task 9: Error and Empty States

- Network error banner with retry
- Empty state with CTA
- Upload failure alert
- Invalid file type alert
- Pull-to-refresh on list

---

## Testing Checklist (for Unit/E2E/A11y agents)

- Page loads and displays documents
- Statistics cards accurate
- Upload video/PDF success
- Delete via swipe
- Grid/list toggle
- Filter by type, search
- Sort options
- Empty state
- Error handling (401, network, invalid file)
- VoiceOver labels, 44pt targets, Dynamic Type

---

## Build Commands

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
make build
make test-unit
```
