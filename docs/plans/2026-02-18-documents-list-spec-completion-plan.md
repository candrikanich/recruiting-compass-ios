# Documents List Spec Completion Plan

> **Status:** Spec not fully implemented. This plan closes gaps between `iOS_SPEC_Phase6_DocumentsList.md` and the current iOS implementation.
>
> **Reference:** `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/planning/iOS_SPEC_Phase6_DocumentsList.md`

---

## 1. Implementation Status Summary

### ✅ Fully Implemented

| Spec Section | Status | Notes |
|--------------|--------|-------|
| **Models** | Done | `Document`, `DocumentType`, `DocumentStatistics` match spec |
| **API Integration** | Done | Fetch, upload (Storage + insert), delete (Storage + DB) |
| **State Management** | Done | Filters, sort, view mode, UserDefaults persistence |
| **Statistics Cards** | Done | 4 cards, horizontal scroll, Phase 5 storage placeholder |
| **Filter Bar** | Done | Search, sort dropdown, filter button, view toggle |
| **Filter Sheet** | Done | Type multi-select, School picker, Shared-only toggle |
| **Document Cards** | Done | Grid + list layouts, type badge, metadata, shared badge |
| **List Swipe Delete** | Done | Swipe actions on list rows |
| **Upload Form** | Done | Type, title, school, version, description, file picker |
| **File Validation** | Done | Extension validation per `DocumentType.allowedExtensions` |
| **Empty/Error States** | Done | ContentUnavailableView, error banner, retry |
| **Pull-to-Refresh** | Done | `.refreshable` on list |
| **Delete Confirmation** | Done | `confirmationDialog` for delete |
| **Navigation** | Done | Documents tab, NavigationLink to detail (placeholder) |
| **Accessibility** | Partial | Labels on buttons; chips and grid delete need refinement |

### ❌ Gaps (Spec Not Met)

| Gap | Spec Requirement | Current State | Priority |
|-----|------------------|---------------|----------|
| 1. Upload progress | "Linear progress bar below file name" with "Percentage text: 45%" | ProgressView + "Uploading..." only | High |
| 2. File size validation | "413: File too large (max 100MB)"; "File exceeds 100MB limit" alert | No size check | High |
| 3. Active filter chips | "Display as removable chips below filter bar" (e.g. "Type: Video ✕") | "Clear filters" button only | Medium |
| 4. Grid delete | List has swipe; grid has no delete path | Grid cards tap → detail; no delete | High |
| 5. FAB size | 64pt diameter circle | 56pt | Low |
| 6. Document detail | "Navigate to document detail page" | Placeholder only ("coming in future update") | Medium* |
| 7. Unit tests | Spec §9 Testing Checklist | No Documents tests | High |
| 8. E2E tests | Spec §9 Happy Path Tests | No Documents E2E | Medium |
| 9. Skeleton loading | "Skeleton screens for 6 cards, shimmer" | ContentUnavailableView + ProgressView | Low |
| 10. Shared badge truncation | "Shared: 20+" for 20+ schools | Exact count always | Low |

\* Document detail may be a separate phase; placeholder satisfies "navigate" for Phase 6.

---

## 2. Implementation Plan

### Task 1: Upload Progress (Spec §6, §8)

**Files:**  
- `DocumentsListViewModel.swift`  
- `DocumentsServiceImpl.swift`  
- `DocumentUploadSheet.swift`

**Changes:**
1. Add upload progress reporting to `DocumentsManaging.uploadDocument` (or use a callback/delegate if Supabase Storage supports progress).
2. If Supabase iOS SDK supports upload progress, pass it to the ViewModel; otherwise keep spinner but add `uploadProgress` display when available.
3. In `DocumentUploadSheet`, show a linear `ProgressView(value: viewModel.uploadProgress)` and percentage text ("\(Int(viewModel.uploadProgress * 100))%") when `isUploading` and `uploadProgress > 0`.

**Spec reference:**  
> "Linear progress bar below file name"  
> "Percentage text: 45%"

---

### Task 2: File Size Validation (100MB)

**Files:**  
- `DocumentsListViewModel.swift`  
- `DocumentUploadSheet.swift` (optional: surface error)

**Changes:**
1. Before calling `documentsService.uploadDocument`, read file size from `selectedFileURL` via `FileManager.default.attributesOfItem(atPath:)` or `URLResourceValues.fileSize`.
2. If size > 100 * 1024 * 1024 (100MB), set `uploadError = "File exceeds 100MB limit. Please compress or choose a smaller file."` and return without uploading.

**Spec reference:**  
> "413: File too large (max 100MB)"  
> "File exceeds 100MB limit. Please compress or choose a smaller file."

---

### Task 3: Active Filter Chips

**Files:**  
- Create `DocumentActiveFilterChips.swift` (follow `ActiveFilterChips`, `SchoolActiveFilterChips`)
- `DocumentsListView.swift`

**Changes:**
1. Use shared `FilterChip` and `FilterChipContainer` from `Shared/Components/`.
2. Create `DocumentActiveFilterChips` that renders chips for:  
   - Search query (if non-empty): `"Search: {query}"`  
   - Selected types: `"Type: {label}"` per type  
   - Selected school: `"School: {name}"`  
   - Shared only: `"Shared only"`
3. Each chip has an X button to clear that filter.
4. Add "Clear filters" in container when `hasActiveFilters`.
5. Insert `DocumentActiveFilterChips` below `DocumentFilterBar` when `viewModel.hasActiveFilters`.

**Spec reference:**  
> "Active Filters: Display as removable chips below filter bar"  
> "Chip: Gray pill with 'X' button, e.g., 'Type: Video ✕'"

---

### Task 4: Grid Delete via Context Menu

**Files:**  
- `DocumentsListView.swift`  
- `DocumentCardView.swift` (if needed for context menu placement)

**Changes:**
1. Add `.contextMenu` to the grid `NavigationLink` (or wrapper) for each document card:
   ```swift
   .contextMenu {
     Button(role: .destructive) {
       documentToDelete = doc
     } label: {
       Label("Delete", systemImage: "trash")
     }
   }
   ```
2. Reuse existing `documentToDelete` + `confirmationDialog` flow.

**Spec reference:**  
> List: "Swipe Actions: Delete" (implemented).  
> Grid: Spec implies delete should be available; context menu is the standard iOS pattern for grid items.

---

### Task 5: FAB Size (64pt)

**File:** `DocumentsListView.swift`

**Change:**
- Update FAB frame from `width: 56, height: 56` to `width: 64, height: 64`.

**Spec reference:**  
> "64pt diameter circle"

---

### Task 6: Document Detail Placeholder Enhancement (Optional)

**File:** `DocumentDetailPlaceholderView.swift`

**Change:**
- Optionally display document metadata (title, type, school) if we fetch the document by id, so the detail stub is more informative.  
- Or leave as-is if Document Detail is a future phase.

**Spec reference:**  
> "Navigate to document detail page" — navigation works; full detail is deferred.

---

### Task 7: Unit Tests

**Files to create:**
- `TheRecruitingCompassTests/Features/Documents/Models/DocumentTests.swift`
- `TheRecruitingCompassTests/Features/Documents/Models/DocumentTypeTests.swift`
- `TheRecruitingCompassTests/Features/Documents/Services/MockDocumentsService.swift`
- `TheRecruitingCompassTests/Features/Documents/ViewModels/DocumentsListViewModelTests.swift`

**Test coverage:**
- **Document:** Codable round-trip, `isShared`, `typeEmoji`, `displayDate`
- **DocumentType:** `label`, `allowedExtensions`, `typeEmoji`
- **DocumentsListViewModel:**
  - `loadDocuments` success/failure
  - `filteredDocuments` (search, type, school, shared)
  - `sortedDocuments` (newest, oldest, name, type, shared)
  - `statistics` (total, shared, mostCommonType)
  - `deleteDocument` removes from list on success
  - File size validation (100MB)
  - Upload validation (type, title, file required)

**Reference:** `TheRecruitingCompassTests/Features/Events/`, `Schools/` patterns.

---

### Task 8: E2E Tests

**File to create:**  
- `TheRecruitingCompassUITests/Features/Documents/DocumentsListE2ETests.swift`

**Scenarios:**
- Tab to Documents, verify list or empty state loads
- Empty state: verify CTA
- Grid/list toggle
- Filter button opens sheet
- Sort dropdown works
- Upload button opens sheet
- Statistics cards visible

**Reference:** `TheRecruitingCompassUITests/Features/` patterns, `docs/AGENT_TEAM_Phase6_DocumentsList.md`.

---

### Task 9: Accessibility Tests

**File to create:**  
- `TheRecruitingCompassTests/Features/Documents/Accessibility/DocumentsListAccessibilityTests.swift`

**Verify:**
- VoiceOver labels for cards, upload button, filter button
- 44pt minimum touch targets
- Filter chips accessible

---

## 3. Suggested Implementation Order

| Order | Task | Dependencies | Effort |
|-------|------|--------------|--------|
| 1 | Task 2: File size validation | None | Small |
| 2 | Task 4: Grid context menu delete | None | Small |
| 3 | Task 5: FAB 64pt | None | Trivial |
| 4 | Task 1: Upload progress | Supabase SDK capabilities | Medium |
| 5 | Task 3: Active filter chips | Shared FilterChip | Medium |
| 6 | Task 7: Unit tests | All ViewModel changes | Medium |
| 7 | Task 8: E2E tests | None | Medium |
| 8 | Task 9: Accessibility tests | Filter chips | Small |
| 9 | Task 6: Detail enhancement | Optional | Small |

---

## 4. Patterns & Standards

- **Architecture:** MVVM, `@Observable` ViewModels, protocol-based services
- **DI:** `DocumentsManaging`, `SchoolsManaging`, `AuthManaging`, `FamilyManager`
- **UI:** SwiftUI, semantic fonts, `ContentUnavailableView`, `FilterChip`/`FilterChipContainer`
- **Testing:** Unit (ViewModel, models), E2E (Documents tab flows), Accessibility (VoiceOver, 44pt)

---

## 5. Verification Checklist

After implementation:

- [ ] `make build` passes
- [ ] `make test-unit` passes (including new Documents tests)
- [ ] Upload rejects files > 100MB with correct message
- [ ] Upload shows progress (if SDK supports it)
- [ ] Grid cards have context menu → Delete
- [ ] Active filter chips appear and clear correctly
- [ ] FAB is 64pt
- [ ] Spec §9 Testing Checklist items pass
- [ ] VoiceOver and 44pt targets verified
