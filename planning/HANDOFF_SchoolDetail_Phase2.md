# School Detail Phase 2 - Implementation Handoff

**Created:** February 10, 2026
**Phase:** 2 of 4 (Editing & Notes)
**Estimated Time:** 1 day
**Status:** Ready to start

---

## Executive Summary

Phase 1 of School Detail is **COMPLETE** and **BUILD SUCCEEDED**. The foundation is solid:
- Models extended with all Phase 1-2 fields
- Services implement fetch, status update, and history
- ViewModel orchestrates state
- Basic detail view displays school header, status picker, and history timeline
- Navigation from Schools List works perfectly

**Phase 2 Goal:** Add interactive editing capabilities - favorite toggle, notes (shared and private), pros/cons lists, and basic information editing.

---

## What Was Completed in Phase 1

### ✅ Models Created/Extended

**Location:** `TheRecruitingCompass/Features/Schools/Models/`

1. **SchoolStatus.swift** - Enhanced with `badgeColors` tuple
   ```swift
   var badgeColors: (background: Color, text: Color) {
     switch self {
     case .interested: return (Color.blue.opacity(0.15), .blue)
     // ... 8 more cases
     }
   }
   ```

2. **PriorityTier.swift** - Added `badgeColor` property
   ```swift
   var badgeColor: Color {
     switch self {
     case .a: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
     case .b: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
     case .c: return Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
     }
   }
   ```

3. **SchoolStatusHistory.swift** - New model for status timeline
   ```swift
   struct SchoolStatusHistory: Identifiable, Codable, Sendable {
     let id: String
     let schoolId: String
     let previousStatus: String?
     let newStatus: String
     let changedBy: String
     let changedAt: Date  // Custom ISO8601 decoder
     let notes: String?
     let createdAt: Date
   }
   ```

4. **School.swift** - Extended with Phase 2 fields
   - Added `privateNotes: [String: String]?` - User-keyed private notes
   - Extended `AcademicInfo` with 8 new fields:
     - `baseballFacilityAddress`, `mascot`, `undergradSize`
     - `carnegieSize`, `tuitionInState`, `tuitionOutOfState`
     - `admissionRate`, `distanceFromHome`
   - Added helper: `func privateNote(for userId: String) -> String?`

### ✅ Services Implemented

**Location:** `TheRecruitingCompass/Features/Schools/Services/`

**SchoolsManaging.swift** - Extended protocol:
```swift
func fetchSchool(id: String, familyUnitId: String) async throws -> School
func updateStatus(...) async throws -> School
func fetchStatusHistory(schoolId: String) async throws -> [SchoolStatusHistory]
```

**SchoolsServiceImpl.swift** - Implemented:
- `fetchSchool()` - Single school with family scoping
- `updateStatus()` - Two-step: update school + create history entry
- `fetchStatusHistory()` - Load timeline ordered by date descending

### ✅ ViewModel Created

**Location:** `TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift`

**State Properties:**
```swift
@Published var school: School?
@Published var isLoading = false
@Published var errorMessage: String?
@Published var statusHistory: [SchoolStatusHistory] = []
@Published var isUpdatingStatus = false
```

**Key Methods (Phase 1):**
- `loadSchool()` - Parallel fetch of school + history
- `updateStatus(to:)` - Update status with history creation
- `toggleFavorite()` - ✅ Already implemented (optimistic update)

**Dependencies:**
- `SchoolsManaging` service
- `AuthManaging` for user ID
- `FamilyManager` for family scoping

### ✅ View Components Created

**Location:** `TheRecruitingCompass/Features/Schools/Components/`

1. **SchoolDetailHeader.swift** - Header with logo, name, badges, favorite star
2. **SchoolStatusHistorySection.swift** - Timeline of status changes
3. **Badge components** - Status, Priority, Division, Size, Conference

**Location:** `TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift`

Main scrollable view with:
- Loading state
- Error state
- Detail content (header + status picker + history)
- Pull-to-refresh
- Navigation integration

### ✅ Build Status

```bash
** BUILD SUCCEEDED **
```

- 0 compilation errors
- Minor actor isolation warnings (existing pattern, safe to ignore)
- All existing tests compile
- Navigation from Schools List → School Detail works

---

## Phase 2: Editing & Notes Implementation

### Overview

Phase 2 adds interactive editing capabilities to the School Detail view:
1. **Favorite toggle** (ViewModel already done, just wire up UI)
2. **Shared notes** - Edit and save notes visible to all family members
3. **Private notes** - Edit and save notes visible only to current user
4. **Pros & Cons** - Add/remove items in two side-by-side lists
5. **Basic Info** - Edit school metadata (address, mascot, website, etc.)

### Phase 2 Service Extensions Required

**File:** `TheRecruitingCompass/Features/Schools/Services/SchoolsManaging.swift`

Add these methods to the protocol:
```swift
protocol SchoolsManaging: Sendable {
  // ... existing methods from Phase 1

  // Phase 2 methods
  func updateNotes(id: String, notes: String) async throws -> School
  func updatePrivateNotes(id: String, userId: String, note: String?) async throws -> School
  func addPro(id: String, text: String) async throws -> School
  func removePro(id: String, index: Int) async throws -> School
  func addCon(id: String, text: String) async throws -> School
  func removeCon(id: String, index: Int) async throws -> School
  func updateBasicInfo(id: String, info: EditableBasicInfo) async throws -> School
}
```

**File:** `TheRecruitingCompass/Features/Schools/Services/SchoolsServiceImpl.swift`

Implement these methods (examples):

```swift
func updateNotes(id: String, notes: String) async throws -> School {
  logger.debug("Updating notes for school: \(id)")

  let updated: School = try await supabaseManager.client
    .from("schools")
    .update(["notes": notes])
    .eq("id", value: id)
    .select()
    .single()
    .execute()
    .value

  logger.info("Notes updated for school: \(id)")
  return updated
}

func updatePrivateNotes(id: String, userId: String, note: String?) async throws -> School {
  logger.debug("Updating private notes for school: \(id), user: \(userId)")

  // CRITICAL: Fetch current school to merge private notes
  let current = try await fetchSchool(id: id, familyUnitId: /* need to pass this */)
  var privateNotes = current.privateNotes ?? [:]

  if let note = note, !note.isEmpty {
    privateNotes[userId] = note
  } else {
    privateNotes.removeValue(forKey: userId)
  }

  let updated: School = try await supabaseManager.client
    .from("schools")
    .update(["private_notes": privateNotes])
    .eq("id", value: id)
    .select()
    .single()
    .execute()
    .value

  logger.info("Private notes updated for school: \(id)")
  return updated
}

func addPro(id: String, text: String) async throws -> School {
  logger.debug("Adding pro to school: \(id)")

  // Fetch current school to append to array
  let current = try await fetchSchool(id: id, familyUnitId: /* need familyId */)
  var pros = current.pros
  pros.append(text)

  let updated: School = try await supabaseManager.client
    .from("schools")
    .update(["pros": pros])
    .eq("id", value: id)
    .select()
    .single()
    .execute()
    .value

  logger.info("Pro added to school: \(id)")
  return updated
}

func removePro(id: String, index: Int) async throws -> School {
  logger.debug("Removing pro at index \(index) from school: \(id)")

  let current = try await fetchSchool(id: id, familyUnitId: /* need familyId */)
  var pros = current.pros
  guard index < pros.count else {
    throw SchoolError.invalidIndex
  }
  pros.remove(at: index)

  let updated: School = try await supabaseManager.client
    .from("schools")
    .update(["pros": pros])
    .eq("id", value: id)
    .select()
    .single()
    .execute()
    .value

  logger.info("Pro removed from school: \(id)")
  return updated
}

// Similar for addCon(), removeCon()

func updateBasicInfo(id: String, info: EditableBasicInfo) async throws -> School {
  logger.debug("Updating basic info for school: \(id)")

  // Merge into academic_info JSON field
  let academicInfoUpdate: [String: Any?] = [
    "address": info.address.isEmpty ? nil : info.address,
    "baseball_facility_address": info.baseballFacilityAddress.isEmpty ? nil : info.baseballFacilityAddress,
    "mascot": info.mascot.isEmpty ? nil : info.mascot,
    "undergrad_size": info.undergradSize.isEmpty ? nil : info.undergradSize
  ]

  let update: [String: Any?] = [
    "website": info.website.isEmpty ? nil : info.website,
    "twitter_handle": info.twitterHandle.isEmpty ? nil : info.twitterHandle,
    "instagram_handle": info.instagramHandle.isEmpty ? nil : info.instagramHandle,
    "academic_info": academicInfoUpdate
  ]

  let updated: School = try await supabaseManager.client
    .from("schools")
    .update(update)
    .eq("id", value: id)
    .select()
    .single()
    .execute()
    .value

  logger.info("Basic info updated for school: \(id)")
  return updated
}
```

**IMPORTANT NOTE:** Several methods need `familyUnitId` to fetch the current school. You have two options:
1. **Add familyUnitId parameter** to methods that need it
2. **Store familyUnitId in service** during initialization

**Recommendation:** Add it as a parameter for now, refactor later if needed.

### Phase 2 Models Required

**File:** `TheRecruitingCompass/Features/Schools/Models/EditableBasicInfo.swift`

Create this new model:
```swift
import Foundation

struct EditableBasicInfo {
  var address: String = ""
  var baseballFacilityAddress: String = ""
  var mascot: String = ""
  var undergradSize: String = ""
  var website: String = ""
  var twitterHandle: String = ""
  var instagramHandle: String = ""

  static func from(school: School) -> EditableBasicInfo {
    EditableBasicInfo(
      address: school.academicInfo?.address ?? "",
      baseballFacilityAddress: school.academicInfo?.baseballFacilityAddress ?? "",
      mascot: school.academicInfo?.mascot ?? "",
      undergradSize: school.academicInfo?.undergradSize ?? "",
      website: school.website ?? "",
      twitterHandle: school.twitterHandle ?? "",
      instagramHandle: school.instagramHandle ?? ""
    )
  }
}
```

### Phase 2 ViewModel Extensions

**File:** `TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift`

Add these properties and methods:

```swift
// MARK: - Notes Editing

@Published var isEditingNotes = false
@Published var editedNotes = ""
@Published var isSavingNotes = false

func startEditingNotes() {
  editedNotes = school?.notes ?? ""
  isEditingNotes = true
}

func cancelEditingNotes() {
  editedNotes = ""
  isEditingNotes = false
}

func saveNotes() async {
  guard !editedNotes.isEmpty else { return }

  isSavingNotes = true
  defer { isSavingNotes = false }

  do {
    let updated = try await schoolsService.updateNotes(id: schoolId, notes: editedNotes)
    school = updated
    isEditingNotes = false
    logger.info("Notes saved successfully")
  } catch {
    errorMessage = "Failed to save notes"
    logger.error("Failed to save notes: \(error.localizedDescription)")
  }
}

// MARK: - Private Notes Editing

@Published var isEditingPrivateNotes = false
@Published var editedPrivateNotes = ""
@Published var isSavingPrivateNotes = false

func startEditingPrivateNotes() {
  editedPrivateNotes = privateNoteForCurrentUser
  isEditingPrivateNotes = true
}

func cancelEditingPrivateNotes() {
  editedPrivateNotes = ""
  isEditingPrivateNotes = false
}

func savePrivateNotes() async {
  isSavingPrivateNotes = true
  defer { isSavingPrivateNotes = false }

  do {
    let note = editedPrivateNotes.isEmpty ? nil : editedPrivateNotes
    let updated = try await schoolsService.updatePrivateNotes(
      id: schoolId,
      userId: currentUserId,
      note: note
    )
    school = updated
    isEditingPrivateNotes = false
    logger.info("Private notes saved successfully")
  } catch {
    errorMessage = "Failed to save private notes"
    logger.error("Failed to save private notes: \(error.localizedDescription)")
  }
}

// MARK: - Pros & Cons

@Published var newPro = ""
@Published var newCon = ""
@Published var isAddingPro = false
@Published var isAddingCon = false

func addPro() async {
  guard !newPro.trimmingCharacters(in: .whitespaces).isEmpty else { return }

  isAddingPro = true
  defer { isAddingPro = false }

  do {
    let updated = try await schoolsService.addPro(id: schoolId, text: newPro)
    school = updated
    newPro = ""
    logger.info("Pro added successfully")
  } catch {
    errorMessage = "Failed to add pro"
    logger.error("Failed to add pro: \(error.localizedDescription)")
  }
}

func removePro(at index: Int) async {
  do {
    let updated = try await schoolsService.removePro(id: schoolId, index: index)
    school = updated
    logger.info("Pro removed successfully")
  } catch {
    errorMessage = "Failed to remove pro"
    logger.error("Failed to remove pro: \(error.localizedDescription)")
  }
}

func addCon() async {
  guard !newCon.trimmingCharacters(in: .whitespaces).isEmpty else { return }

  isAddingCon = true
  defer { isAddingCon = false }

  do {
    let updated = try await schoolsService.addCon(id: schoolId, text: newCon)
    school = updated
    newCon = ""
    logger.info("Con added successfully")
  } catch {
    errorMessage = "Failed to add con"
    logger.error("Failed to add con: \(error.localizedDescription)")
  }
}

func removeCon(at index: Int) async {
  do {
    let updated = try await schoolsService.removeCon(id: schoolId, index: index)
    school = updated
    logger.info("Con removed successfully")
  } catch {
    errorMessage = "Failed to remove con"
    logger.error("Failed to remove con: \(error.localizedDescription)")
  }
}

// MARK: - Basic Info Editing

@Published var isEditingBasicInfo = false
@Published var editedBasicInfo = EditableBasicInfo()
@Published var isSavingBasicInfo = false

func startEditingBasicInfo() {
  guard let school else { return }
  editedBasicInfo = EditableBasicInfo.from(school: school)
  isEditingBasicInfo = true
}

func cancelEditingBasicInfo() {
  editedBasicInfo = EditableBasicInfo()
  isEditingBasicInfo = false
}

func saveBasicInfo() async {
  isSavingBasicInfo = true
  defer { isSavingBasicInfo = false }

  do {
    let updated = try await schoolsService.updateBasicInfo(
      id: schoolId,
      info: editedBasicInfo
    )
    school = updated
    isEditingBasicInfo = false
    logger.info("Basic info saved successfully")
  } catch {
    errorMessage = "Failed to save information"
    logger.error("Failed to save basic info: \(error.localizedDescription)")
  }
}
```

### Phase 2 View Components to Create

**1. SchoolNotesSection.swift**

**Location:** `TheRecruitingCompass/Features/Schools/Components/SchoolNotesSection.swift`

```swift
import SwiftUI

struct SchoolNotesSection: View {
  let title: String
  let notes: String
  let isPrivate: Bool
  let isEditing: Bool
  @Binding var editedNotes: String
  let onEdit: () -> Void
  let onSave: () async -> Void
  let onCancel: () -> Void
  let isSaving: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()

        if !isEditing {
          Button("Edit", action: onEdit)
            .accessibilityLabel("Edit \(title.lowercased())")
        }
      }

      if isPrivate {
        Text("Only you can see these notes")
          .font(.caption)
          .foregroundStyle(.secondary)
          .italic()
      }

      if isEditing {
        VStack(spacing: 12) {
          TextEditor(text: $editedNotes)
            .frame(minHeight: 120)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .accessibilityLabel("\(title) editor")

          HStack {
            Button("Cancel", action: onCancel)
              .disabled(isSaving)

            Spacer()

            Button {
              Task { await onSave() }
            } label: {
              if isSaving {
                ProgressView()
                  .progressViewStyle(.circular)
                  .scaleEffect(0.8)
              } else {
                Text("Save")
              }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
          }
        }
      } else {
        Text(notes.isEmpty ? "No notes added yet." : notes)
          .font(.body)
          .foregroundStyle(notes.isEmpty ? .secondary : .primary)
          .italic(notes.isEmpty)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

#Preview {
  VStack(spacing: 16) {
    SchoolNotesSection(
      title: "Notes",
      notes: "Great academic program with strong baseball history.",
      isPrivate: false,
      isEditing: false,
      editedNotes: .constant(""),
      onEdit: {},
      onSave: {},
      onCancel: {},
      isSaving: false
    )

    SchoolNotesSection(
      title: "Private Notes",
      notes: "",
      isPrivate: true,
      isEditing: true,
      editedNotes: .constant("My private thoughts..."),
      onEdit: {},
      onSave: {},
      onCancel: {},
      isSaving: false
    )
  }
  .padding()
}
```

**2. SchoolProsConsSection.swift**

**Location:** `TheRecruitingCompass/Features/Schools/Components/SchoolProsConsSection.swift`

```swift
import SwiftUI

struct SchoolProsConsSection: View {
  let pros: [String]
  let cons: [String]
  @Binding var newPro: String
  @Binding var newCon: String
  let onAddPro: () async -> Void
  let onRemovePro: (Int) async -> Void
  let onAddCon: () async -> Void
  let onRemoveCon: (Int) async -> Void
  let isAddingPro: Bool
  let isAddingCon: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Pros & Cons")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      HStack(alignment: .top, spacing: 16) {
        // Pros column
        VStack(alignment: .leading, spacing: 8) {
          Text("Pros")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.green)

          ForEach(Array(pros.enumerated()), id: \.offset) { index, pro in
            ProItem(text: pro) {
              Task { await onRemovePro(index) }
            }
          }

          HStack(spacing: 8) {
            TextField("Add a pro...", text: $newPro)
              .textFieldStyle(.roundedBorder)
              .onSubmit {
                Task { await onAddPro() }
              }
              .accessibilityLabel("Add pro input")

            Button {
              Task { await onAddPro() }
            } label: {
              if isAddingPro {
                ProgressView()
                  .progressViewStyle(.circular)
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "plus.circle.fill")
                  .foregroundStyle(.green)
                  .font(.title2)
              }
            }
            .frame(width: 44, height: 44)
            .disabled(newPro.trimmingCharacters(in: .whitespaces).isEmpty || isAddingPro)
            .accessibilityLabel("Add pro")
          }
        }
        .frame(maxWidth: .infinity)

        // Cons column
        VStack(alignment: .leading, spacing: 8) {
          Text("Cons")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.red)

          ForEach(Array(cons.enumerated()), id: \.offset) { index, con in
            ConItem(text: con) {
              Task { await onRemoveCon(index) }
            }
          }

          HStack(spacing: 8) {
            TextField("Add a con...", text: $newCon)
              .textFieldStyle(.roundedBorder)
              .onSubmit {
                Task { await onAddCon() }
              }
              .accessibilityLabel("Add con input")

            Button {
              Task { await onAddCon() }
            } label: {
              if isAddingCon {
                ProgressView()
                  .progressViewStyle(.circular)
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "plus.circle.fill")
                  .foregroundStyle(.red)
                  .font(.title2)
              }
            }
            .frame(width: 44, height: 44)
            .disabled(newCon.trimmingCharacters(in: .whitespaces).isEmpty || isAddingCon)
            .accessibilityLabel("Add con")
          }
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

struct ProItem: View {
  let text: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
        .font(.caption)
        .accessibilityHidden(true)

      Text(text)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
          .font(.caption)
      }
      .frame(width: 30, height: 30)
      .accessibilityLabel("Remove \(text)")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.green.opacity(0.1))
    .cornerRadius(8)
  }
}

struct ConItem: View {
  let text: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "xmark.circle.fill")
        .foregroundStyle(.red)
        .font(.caption)
        .accessibilityHidden(true)

      Text(text)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
          .font(.caption)
      }
      .frame(width: 30, height: 30)
      .accessibilityLabel("Remove \(text)")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.red.opacity(0.1))
    .cornerRadius(8)
  }
}

#Preview {
  ScrollView {
    SchoolProsConsSection(
      pros: [
        "Excellent academic reputation",
        "Strong baseball program",
        "Beautiful campus"
      ],
      cons: [
        "Far from home",
        "Expensive tuition",
        "Cold weather"
      ],
      newPro: .constant(""),
      newCon: .constant(""),
      onAddPro: {},
      onRemovePro: { _ in },
      onAddCon: {},
      onRemoveCon: { _ in },
      isAddingPro: false,
      isAddingCon: false
    )
    .padding()
  }
}
```

**3. SchoolBasicInfoSheet.swift**

**Location:** `TheRecruitingCompass/Features/Schools/Components/SchoolBasicInfoSheet.swift`

```swift
import SwiftUI

struct SchoolBasicInfoSheet: View {
  @Binding var info: EditableBasicInfo
  let onSave: () async -> Void
  let onCancel: () -> Void
  let isSaving: Bool

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section("Location") {
          TextField("Campus Address", text: $info.address)
            .textContentType(.fullStreetAddress)

          TextField("Baseball Facility Address", text: $info.baseballFacilityAddress)
            .textContentType(.fullStreetAddress)
        }

        Section("School Details") {
          TextField("Mascot", text: $info.mascot)

          TextField("Undergrad Size", text: $info.undergradSize)
            .keyboardType(.numberPad)
        }

        Section("Online Presence") {
          TextField("Website", text: $info.website)
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocapitalization(.none)

          TextField("Twitter Handle", text: $info.twitterHandle)
            .autocapitalization(.none)

          TextField("Instagram Handle", text: $info.instagramHandle)
            .autocapitalization(.none)
        }
      }
      .navigationTitle("Edit Information")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onCancel()
            dismiss()
          }
          .disabled(isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              await onSave()
              dismiss()
            }
          } label: {
            if isSaving {
              ProgressView()
                .progressViewStyle(.circular)
            } else {
              Text("Save")
            }
          }
          .disabled(isSaving)
        }
      }
    }
  }
}

#Preview {
  SchoolBasicInfoSheet(
    info: .constant(EditableBasicInfo(
      address: "123 University Ave",
      baseballFacilityAddress: "456 Stadium Dr",
      mascot: "Longhorns",
      undergradSize: "40000",
      website: "utexas.edu",
      twitterHandle: "@TexasBaseball",
      instagramHandle: "@texasbaseball"
    )),
    onSave: {},
    onCancel: {},
    isSaving: false
  )
}
```

### Phase 2 Update Main View

**File:** `TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift`

Add these sections to the `detailContent()` method (after status history):

```swift
@ViewBuilder
private func detailContent(school: School) -> some View {
  VStack(spacing: 0) {
    SchoolDetailHeader(
      school: school,
      onToggleFavorite: {
        Task { await viewModel.toggleFavorite() }
      }
    )

    Divider()

    VStack(spacing: 24) {
      statusPickerSection(school: school)

      SchoolStatusHistorySection(history: viewModel.statusHistory)
        .padding(.horizontal)

      // NEW PHASE 2 SECTIONS

      SchoolNotesSection(
        title: "Notes",
        notes: school.notes ?? "",
        isPrivate: false,
        isEditing: viewModel.isEditingNotes,
        editedNotes: $viewModel.editedNotes,
        onEdit: { viewModel.startEditingNotes() },
        onSave: { await viewModel.saveNotes() },
        onCancel: { viewModel.cancelEditingNotes() },
        isSaving: viewModel.isSavingNotes
      )
      .padding(.horizontal)

      SchoolNotesSection(
        title: "Private Notes",
        notes: viewModel.privateNoteForCurrentUser,
        isPrivate: true,
        isEditing: viewModel.isEditingPrivateNotes,
        editedNotes: $viewModel.editedPrivateNotes,
        onEdit: { viewModel.startEditingPrivateNotes() },
        onSave: { await viewModel.savePrivateNotes() },
        onCancel: { viewModel.cancelEditingPrivateNotes() },
        isSaving: viewModel.isSavingPrivateNotes
      )
      .padding(.horizontal)

      SchoolProsConsSection(
        pros: school.pros,
        cons: school.cons,
        newPro: $viewModel.newPro,
        newCon: $viewModel.newCon,
        onAddPro: { await viewModel.addPro() },
        onRemovePro: { index in await viewModel.removePro(at: index) },
        onAddCon: { await viewModel.addCon() },
        onRemoveCon: { index in await viewModel.removeCon(at: index) },
        isAddingPro: viewModel.isAddingPro,
        isAddingCon: viewModel.isAddingCon
      )
      .padding(.horizontal)

      basicInfoSection(school: school)
    }
    .padding(.vertical)
  }
}

@ViewBuilder
private func basicInfoSection(school: School) -> some View {
  VStack(alignment: .leading, spacing: 12) {
    HStack {
      Text("Information")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Spacer()

      Button("Edit") {
        viewModel.startEditingBasicInfo()
      }
      .accessibilityLabel("Edit school information")
    }

    if let info = school.academicInfo {
      VStack(alignment: .leading, spacing: 8) {
        if let address = info.address {
          InfoRow(label: "Campus Address", value: address)
        }

        if let facility = info.baseballFacilityAddress {
          InfoRow(label: "Baseball Facility", value: facility)
        }

        if let mascot = info.mascot {
          InfoRow(label: "Mascot", value: mascot)
        }

        if let size = info.undergradSize {
          InfoRow(label: "Undergrad Size", value: size)
        }
      }
    }

    if let website = school.website {
      Link(destination: URL(string: "https://\(website)")!) {
        Label("Visit Website", systemImage: "safari")
      }
    }
  }
  .padding()
  .background(Color(.systemGray6))
  .cornerRadius(12)
  .padding(.horizontal)
  .sheet(isPresented: $viewModel.isEditingBasicInfo) {
    SchoolBasicInfoSheet(
      info: $viewModel.editedBasicInfo,
      onSave: { await viewModel.saveBasicInfo() },
      onCancel: { viewModel.cancelEditingBasicInfo() },
      isSaving: viewModel.isSavingBasicInfo
    )
  }
}

struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .top) {
      Text(label + ":")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.subheadline)
        .multilineTextAlignment(.trailing)
    }
  }
}
```

---

## Testing Requirements for Phase 2

### Unit Tests

**File:** `TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailViewModelTests.swift`

Create this test file with these test cases:

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolDetailViewModelTests: XCTestCase {
  var viewModel: SchoolDetailViewModel!
  var mockService: MockSchoolsService!
  var mockAuth: MockAuthManager!
  var mockFamily: MockFamilyManager!

  override func setUp() async throws {
    mockService = MockSchoolsService()
    mockAuth = MockAuthManager()
    mockFamily = MockFamilyManager()

    mockAuth.user = User(id: "user-1", email: "test@example.com", role: .parent)
    mockFamily.familyUnitId = "family-1"

    viewModel = SchoolDetailViewModel(
      schoolId: "school-1",
      schoolsService: mockService,
      authManager: mockAuth,
      familyManager: mockFamily
    )
  }

  // MARK: - Notes Tests

  func testStartEditingNotes() async throws {
    // Given
    mockService.mockSchool = createMockSchool(notes: "Existing notes")
    await viewModel.loadSchool()

    // When
    viewModel.startEditingNotes()

    // Then
    XCTAssertTrue(viewModel.isEditingNotes)
    XCTAssertEqual(viewModel.editedNotes, "Existing notes")
  }

  func testSaveNotes() async throws {
    // Given
    mockService.mockSchool = createMockSchool(notes: "Old notes")
    await viewModel.loadSchool()
    viewModel.startEditingNotes()
    viewModel.editedNotes = "New notes"

    // When
    await viewModel.saveNotes()

    // Then
    XCTAssertFalse(viewModel.isEditingNotes)
    XCTAssertEqual(mockService.lastUpdatedNotes, "New notes")
    XCTAssertEqual(viewModel.school?.notes, "New notes")
  }

  func testCancelEditingNotes() async throws {
    // Given
    viewModel.startEditingNotes()
    viewModel.editedNotes = "Some edits"

    // When
    viewModel.cancelEditingNotes()

    // Then
    XCTAssertFalse(viewModel.isEditingNotes)
    XCTAssertTrue(viewModel.editedNotes.isEmpty)
  }

  // MARK: - Private Notes Tests

  func testSavePrivateNotes() async throws {
    // Given
    mockService.mockSchool = createMockSchool(privateNotes: [:])
    await viewModel.loadSchool()
    viewModel.startEditingPrivateNotes()
    viewModel.editedPrivateNotes = "My private thoughts"

    // When
    await viewModel.savePrivateNotes()

    // Then
    XCTAssertFalse(viewModel.isEditingPrivateNotes)
    XCTAssertEqual(mockService.lastUpdatedPrivateNote, "My private thoughts")
    XCTAssertEqual(mockService.lastPrivateNoteUserId, "user-1")
  }

  func testPrivateNoteForCurrentUser() async throws {
    // Given
    mockService.mockSchool = createMockSchool(
      privateNotes: ["user-1": "My note", "user-2": "Other note"]
    )
    await viewModel.loadSchool()

    // When
    let note = viewModel.privateNoteForCurrentUser

    // Then
    XCTAssertEqual(note, "My note")
  }

  // MARK: - Pros & Cons Tests

  func testAddPro() async throws {
    // Given
    mockService.mockSchool = createMockSchool(pros: ["Existing pro"])
    await viewModel.loadSchool()
    viewModel.newPro = "New pro"

    // When
    await viewModel.addPro()

    // Then
    XCTAssertEqual(mockService.lastAddedPro, "New pro")
    XCTAssertTrue(viewModel.newPro.isEmpty)
    XCTAssertEqual(viewModel.school?.pros.count, 2)
  }

  func testRemovePro() async throws {
    // Given
    mockService.mockSchool = createMockSchool(pros: ["Pro 1", "Pro 2"])
    await viewModel.loadSchool()

    // When
    await viewModel.removePro(at: 0)

    // Then
    XCTAssertEqual(mockService.lastRemovedProIndex, 0)
    XCTAssertEqual(viewModel.school?.pros.count, 1)
  }

  func testAddCon() async throws {
    // Given
    mockService.mockSchool = createMockSchool(cons: [])
    await viewModel.loadSchool()
    viewModel.newCon = "New con"

    // When
    await viewModel.addCon()

    // Then
    XCTAssertEqual(mockService.lastAddedCon, "New con")
    XCTAssertTrue(viewModel.newCon.isEmpty)
  }

  // MARK: - Basic Info Tests

  func testSaveBasicInfo() async throws {
    // Given
    mockService.mockSchool = createMockSchool()
    await viewModel.loadSchool()
    viewModel.startEditingBasicInfo()
    viewModel.editedBasicInfo.mascot = "Longhorns"
    viewModel.editedBasicInfo.website = "utexas.edu"

    // When
    await viewModel.saveBasicInfo()

    // Then
    XCTAssertFalse(viewModel.isEditingBasicInfo)
    XCTAssertEqual(mockService.lastUpdatedBasicInfo?.mascot, "Longhorns")
  }

  // MARK: - Helper

  private func createMockSchool(
    notes: String? = nil,
    privateNotes: [String: String]? = nil,
    pros: [String] = [],
    cons: [String] = []
  ) -> School {
    School(
      id: "school-1",
      userId: "user-1",
      name: "Test University",
      location: "Austin, TX",
      city: "Austin",
      state: "TX",
      division: "D1",
      conference: "Big 12",
      ranking: nil,
      isFavorite: false,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "interested",
      statusChangedAt: nil,
      priorityTier: nil,
      notes: notes,
      privateNotes: privateNotes,
      pros: pros,
      cons: cons,
      offerDetails: nil,
      academicInfo: nil,
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      fitScore: nil,
      fitTier: nil,
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z"
    )
  }
}
```

### Mock Service Extensions

**File:** `TheRecruitingCompassTests/Mocks/MockSchoolsService.swift`

Add these properties and methods:

```swift
final class MockSchoolsService: SchoolsManaging {
  // ... existing properties

  // Phase 2 tracking
  var lastUpdatedNotes: String?
  var lastUpdatedPrivateNote: String?
  var lastPrivateNoteUserId: String?
  var lastAddedPro: String?
  var lastRemovedProIndex: Int?
  var lastAddedCon: String?
  var lastRemovedConIndex: Int?
  var lastUpdatedBasicInfo: EditableBasicInfo?

  func updateNotes(id: String, notes: String) async throws -> School {
    lastUpdatedNotes = notes
    var updated = mockSchool!
    // Update mockSchool.notes
    return updated
  }

  func updatePrivateNotes(id: String, userId: String, note: String?) async throws -> School {
    lastUpdatedPrivateNote = note
    lastPrivateNoteUserId = userId
    var updated = mockSchool!
    // Update mockSchool.privateNotes
    return updated
  }

  func addPro(id: String, text: String) async throws -> School {
    lastAddedPro = text
    var updated = mockSchool!
    // Append to mockSchool.pros
    return updated
  }

  func removePro(id: String, index: Int) async throws -> School {
    lastRemovedProIndex = index
    var updated = mockSchool!
    // Remove from mockSchool.pros
    return updated
  }

  // Similar for addCon, removeCon, updateBasicInfo
}
```

### Acceptance Criteria

Phase 2 is complete when:
- [ ] All 7 service methods implemented and tested
- [ ] 15+ ViewModel unit tests passing
- [ ] All 3 view components render correctly
- [ ] Favorite star toggles with optimistic update
- [ ] Shared notes edit and save
- [ ] Private notes edit and save (isolated per user)
- [ ] Pros/cons add and remove work
- [ ] Basic info sheet edits and saves
- [ ] Build succeeds with 0 errors
- [ ] Pull-to-refresh reloads edited data
- [ ] All accessibility labels present

---

## Known Issues & Gotchas

### 1. FamilyUnitId Parameter

Several Phase 2 service methods need `familyUnitId` to fetch current school state before updating. You have two options:

**Option A (Recommended for now):** Pass familyUnitId as parameter
```swift
func updatePrivateNotes(id: String, familyUnitId: String, userId: String, note: String?) async throws -> School
```

**Option B:** Store in ViewModel and pass from there
```swift
// In ViewModel
guard let familyId = familyManager.familyUnitId else { return }
try await schoolsService.updatePrivateNotes(id: schoolId, familyUnitId: familyId, userId: currentUserId, note: note)
```

### 2. Private Notes Merge Logic

**CRITICAL:** When updating private notes, you MUST:
1. Fetch current school
2. Get existing `privateNotes` dictionary
3. Merge/update only the current user's entry
4. Save entire dictionary back

**Why:** Multiple family members can have private notes on the same school. Replacing the entire dictionary will delete other users' notes.

### 3. Array Mutations (Pros/Cons)

When adding/removing pros/cons:
1. Fetch current school
2. Mutate the array
3. Update school with new array

**Why:** Supabase doesn't support array append/remove operations directly. You must send the entire updated array.

### 4. Actor Isolation Warnings

You'll see warnings about main actor isolation in ViewModels. These are **safe to ignore** - they follow the established pattern from CoachDetailViewModel.

Example:
```
warning: call to main actor-isolated initializer 'init(supabaseManager:)' in a synchronous nonisolated context
```

This is expected and will be resolved at build time.

### 5. TextField onSubmit

When using TextFields for pros/cons input, add `.onSubmit` handlers to allow "Return" key submission:

```swift
TextField("Add a pro...", text: $newPro)
  .onSubmit {
    Task { await onAddPro() }
  }
```

### 6. Empty String Validation

Always trim whitespace before checking if input is empty:

```swift
guard !newPro.trimmingCharacters(in: .whitespaces).isEmpty else { return }
```

### 7. Loading States

Each editing operation should have its own loading state:
- `isSavingNotes`
- `isSavingPrivateNotes`
- `isAddingPro`
- `isAddingCon`
- `isSavingBasicInfo`

This allows granular UI feedback and prevents race conditions.

---

## Quick Start Commands

### Build & Test

```bash
cd /Users/chrisandrikanich/Documents/Workspaces/Personal/TheRecruitingCompass/recruiting-compass-ios-fresh/TheRecruitingCompass

# Build
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run tests
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### File Structure

```
TheRecruitingCompass/Features/Schools/
├── Models/
│   ├── SchoolStatus.swift ✅
│   ├── PriorityTier.swift ✅
│   ├── SchoolStatusHistory.swift ✅
│   └── EditableBasicInfo.swift ❌ CREATE THIS
├── Services/
│   ├── SchoolsManaging.swift ✅ EXTEND
│   └── SchoolsServiceImpl.swift ✅ IMPLEMENT 7 METHODS
├── ViewModels/
│   └── SchoolDetailViewModel.swift ✅ ADD PHASE 2 METHODS
├── Components/
│   ├── SchoolDetailHeader.swift ✅
│   ├── SchoolStatusHistorySection.swift ✅
│   ├── SchoolNotesSection.swift ❌ CREATE THIS
│   ├── SchoolProsConsSection.swift ❌ CREATE THIS
│   └── SchoolBasicInfoSheet.swift ❌ CREATE THIS
└── Views/
    └── SchoolDetailView.swift ✅ ADD PHASE 2 SECTIONS
```

---

## Implementation Checklist

### Step 1: Models (15 min)
- [ ] Create `EditableBasicInfo.swift` model

### Step 2: Services (1 hour)
- [ ] Extend `SchoolsManaging` protocol with 7 methods
- [ ] Implement `updateNotes()` in `SchoolsServiceImpl`
- [ ] Implement `updatePrivateNotes()` with merge logic
- [ ] Implement `addPro()`, `removePro()`
- [ ] Implement `addCon()`, `removeCon()`
- [ ] Implement `updateBasicInfo()`

### Step 3: ViewModel (1 hour)
- [ ] Add all Phase 2 @Published properties
- [ ] Implement notes editing methods (4 methods)
- [ ] Implement private notes editing methods (4 methods)
- [ ] Implement pros/cons methods (4 methods)
- [ ] Implement basic info editing methods (3 methods)

### Step 4: View Components (2 hours)
- [ ] Create `SchoolNotesSection.swift`
- [ ] Create `SchoolProsConsSection.swift` with ProItem/ConItem
- [ ] Create `SchoolBasicInfoSheet.swift`
- [ ] Add InfoRow helper struct

### Step 5: Update Main View (30 min)
- [ ] Add notes section to `SchoolDetailView`
- [ ] Add private notes section
- [ ] Add pros/cons section
- [ ] Add basic info section with sheet
- [ ] Wire up all callbacks

### Step 6: Testing (2 hours)
- [ ] Create `SchoolDetailViewModelTests.swift`
- [ ] Write 15+ test cases
- [ ] Extend `MockSchoolsService` with Phase 2 methods
- [ ] Run all tests and verify passing

### Step 7: Build & Verify (30 min)
- [ ] Build project (should succeed)
- [ ] Fix any compilation errors
- [ ] Test manually in simulator
- [ ] Verify accessibility labels

---

## Success Metrics

Phase 2 is **COMPLETE** when:
1. ✅ Build succeeds with 0 errors
2. ✅ 15+ unit tests passing
3. ✅ All 5 editing features work:
   - Favorite toggle
   - Notes edit/save
   - Private notes edit/save
   - Pros/cons add/remove
   - Basic info edit/save
4. ✅ Pull-to-refresh reloads edited data
5. ✅ Error handling shows user-friendly messages
6. ✅ Loading states display correctly
7. ✅ Accessibility labels on all new components

---

## Next Steps After Phase 2

Once Phase 2 is complete:
1. **Code Review** - Use `code-reviewer` agent
2. **Commit** - Create detailed commit message
3. **Phase 3** - Fit score, College Scorecard API, map view
4. **Phase 4** - Coaches panel, actions, delete

---

## Questions?

If you encounter issues:
1. Check the implementation plan: `/planning/IMPLEMENTATION_PLAN_SchoolDetail.md`
2. Reference CoachDetailView/ViewModel for similar patterns
3. Look at existing test files for test structure examples

**Estimated Phase 2 Time:** 6-8 hours (1 full day)

---

**Ready to start? Begin with Step 1: Create EditableBasicInfo model!**
