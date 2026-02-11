# Add School Feature - Complete Spec Implementation Plan

**Project:** The Recruiting Compass iOS App
**Created:** February 11, 2026
**Status:** 75% Complete → 100% Spec Compliance
**Estimated Time:** 2-3 days

---

## Executive Summary

**Current State:** Phases 1-3 (NCAA, Autocomplete, Enrichment) implemented but **uncommitted** and **untested**.
**Missing:** Phase 4 (Duplicate Detection), Phase 5 polish, Phase 6 (Testing & Docs)
**Blocker:** Cannot commit Phases 1-3 without tests (violates TDD standards)

**Critical Path:**
1. Add tests for Phases 1-3 (BLOCKER)
2. Implement Phase 4 (Duplicate Detection)
3. Polish Phase 5 (Auto-Filled Badges)
4. Commit all phases together with full test coverage

---

## Phase 1: Testing for Implemented Features (HIGH PRIORITY)

**Goal:** Add comprehensive tests for Phases 1-3 before committing
**Time:** 8-10 hours

### 1.1: NCAA Database Tests (2 hours)

Create: `TheRecruitingCompassTests/Features/Schools/Services/NcaaDatabaseTests.swift`

**Test Cases (15 tests):**
- ✅ Exact name match (D1, D2, D3)
- ✅ Partial name match (>8 chars)
- ✅ Fuzzy match (Levenshtein distance ≤ 2)
- ✅ No match returns nil
- ✅ Case-insensitive matching
- ✅ Name normalization (strip "University", "College")
- ✅ Lookup caching (same name, same result)
- ✅ JSON file loading (all 3 divisions)
- ✅ Empty school name returns nil
- ✅ Special characters in school name

### 1.2: College Scorecard Service Tests (3 hours)

Create: `TheRecruitingCompassTests/Features/Schools/Services/CollegeScorecardServiceTests.swift`

**Test Cases (20 tests):**
- ✅ Search colleges with valid query (3+ chars)
- ✅ Search with < 3 chars throws error
- ✅ Search returns results with correct fields
- ✅ Search handles empty results
- ✅ Lookup college by name returns full data
- ✅ Lookup handles missing college
- ✅ API key missing error handling
- ✅ Rate limit error handling
- ✅ Network error handling
- ✅ Server error handling
- ✅ Response parsing (College Scorecard format)
- ✅ Null field handling in API response
- ✅ URL construction with query parameters

### 1.3: AddSchoolViewModel Autocomplete Tests (3 hours)

Create: `TheRecruitingCompassTests/Features/Schools/ViewModels/AddSchoolViewModel+AutocompleteTests.swift`

**Test Cases (25 tests):**
- ✅ performAutocompleteSearch() with valid query
- ✅ Search query < 3 chars clears results
- ✅ Search sets isSearching = true during search
- ✅ Search populates searchResults on success
- ✅ Search sets searchError on API key missing
- ✅ Search sets searchError on network error
- ✅ Search sets searchError on rate limit
- ✅ selectCollege() auto-fills name, city, state, location, website
- ✅ selectCollege() triggers NCAA lookup
- ✅ selectCollege() triggers scorecard enrichment
- ✅ selectCollege() clears search results
- ✅ selectCollege() announces for accessibility
- ✅ clearSelection() clears all auto-filled fields
- ✅ clearSelection() clears selectedCollege
- ✅ clearSelection() announces for accessibility

### 1.4: AddSchoolViewModel Enrichment Tests (2 hours)

Create: `TheRecruitingCompassTests/Features/Schools/ViewModels/AddSchoolViewModel+EnrichmentTests.swift`

**Test Cases (15 tests):**
- ✅ performScorecardEnrichment() with valid college name
- ✅ Enrichment sets isEnrichmentLoading = true
- ✅ Enrichment populates scorecardData on success
- ✅ Enrichment handles no data found (silent)
- ✅ Enrichment handles API key missing (silent)
- ✅ Enrichment handles network error (silent)
- ✅ Enrichment announces for accessibility on success
- ✅ clearEnrichment() clears all enrichment state
- ✅ submitSchool() includes scorecardData in request

### 1.5: AddSchoolViewModel NCAA Tests (1 hour)

Create: `TheRecruitingCompassTests/Features/Schools/ViewModels/AddSchoolViewModel+NcaaLookupTests.swift`

**Test Cases (10 tests):**
- ✅ performNcaaLookup() with valid school name
- ✅ NCAA lookup auto-fills division and conference
- ✅ NCAA lookup skips if division already set
- ✅ NCAA lookup skips if name is empty
- ✅ NCAA lookup handles no match (silent)
- ✅ NCAA lookup announces for accessibility on success

### 1.6: Component Accessibility Tests (1 hour)

Create: `TheRecruitingCompassTests/Features/Schools/Components/AddSchoolAccessibilityTests.swift`

**Test Cases (15 tests):**
- ✅ SchoolAutocompleteDropdown VoiceOver labels
- ✅ SelectedCollegeCard accessibility
- ✅ CollegeScorecardDataDisplay accessibility
- ✅ AutoFilledBadge accessibility
- ✅ Autocomplete toggle accessibility
- ✅ Search field accessibility hints

**Total Phase 1:** ~100 new tests, 8-10 hours

---

## Phase 2: Duplicate Detection (HIGH PRIORITY)

**Goal:** Implement full duplicate detection per spec
**Time:** 6-8 hours

### 2.1: Models (1 hour)

Create: `TheRecruitingCompass/Features/Schools/Models/DuplicateResult.swift`

```swift
struct DuplicateResult {
  let duplicate: School?
  let matchType: DuplicateMatchType?

  var isDuplicate: Bool {
    duplicate != nil
  }
}

enum DuplicateMatchType: String, CaseIterable {
  case name = "name"
  case domain = "domain"
  case ncaaId = "ncaa_id"

  var displayLabel: String {
    switch self {
    case .name: return "Name Match"
    case .domain: return "Website Domain"
    case .ncaaId: return "NCAA ID"
    }
  }

  var badgeColor: Color {
    switch self {
    case .name: return .red
    case .domain: return .yellow
    case .ncaaId: return .orange
    }
  }
}
```

### 2.2: Duplicate Detector Service (3 hours)

Create: `TheRecruitingCompass/Features/Schools/Services/DuplicateDetector.swift`

```swift
struct DuplicateDetector {

  /// Check all duplicate criteria in priority order: name > domain > NCAA ID
  static func findDuplicate(
    in existingSchools: [School],
    for input: SchoolCreateRequest
  ) -> DuplicateResult {

    // 1. Name match (case-insensitive exact)
    if let nameMatch = existingSchools.first(where: {
      $0.name.lowercased() == input.name.trimmingCharacters(in: .whitespaces).lowercased()
    }) {
      return DuplicateResult(duplicate: nameMatch, matchType: .name)
    }

    // 2. Domain match (extract hostname, compare)
    if let website = input.website,
       let inputDomain = extractDomain(from: website) {
      if let domainMatch = existingSchools.first(where: {
        guard let existingDomain = extractDomain(from: $0.website ?? "") else { return false }
        return existingDomain == inputDomain
      }) {
        return DuplicateResult(duplicate: domainMatch, matchType: .domain)
      }
    }

    // 3. NCAA ID match (if available in future)
    // Skipped for now as School model doesn't have ncaaId field

    return DuplicateResult(duplicate: nil, matchType: nil)
  }

  private static func extractDomain(from urlString: String) -> String? {
    guard let url = URL(string: urlString),
          let host = url.host else { return nil }
    // Strip "www." prefix
    return host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
  }
}
```

**Tests (10 tests):**
- ✅ Exact name match
- ✅ Case-insensitive name match
- ✅ Domain match (with and without www)
- ✅ No match
- ✅ Multiple schools, first match wins
- ✅ extractDomain() handles various URL formats

### 2.3: Duplicate Dialog Component (2 hours)

Create: `TheRecruitingCompass/Features/Schools/Components/DuplicateSchoolDialog.swift`

```swift
struct DuplicateSchoolDialog: View {
  let duplicate: School
  let matchType: DuplicateMatchType
  let onCancel: () -> Void
  let onProceed: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      // Header
      Text("⚠️ Duplicate School Detected")
        .font(.title2)
        .fontWeight(.bold)
        .accessibilityAddTraits(.isHeader)

      // Description
      Text("A school already exists that matches your entry...")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)

      // Match Type Badge
      HStack {
        Text("Match Type:")
          .font(.subheadline)
        Text(matchType.displayLabel)
          .font(.subheadline)
          .fontWeight(.semibold)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(matchType.badgeColor.opacity(0.2))
          .foregroundColor(matchType.badgeColor)
          .cornerRadius(8)
      }

      // Existing School Card
      VStack(alignment: .leading, spacing: 8) {
        Text("Existing School")
          .font(.caption)
          .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 4) {
          Text(duplicate.name)
            .font(.headline)

          if let division = duplicate.division, let conference = duplicate.conference {
            Text("Division: \(division.displayName) - \(conference)")
              .font(.subheadline)
          }

          if let location = duplicate.location {
            Text("Location: \(location)")
              .font(.subheadline)
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
      }

      // Actions
      HStack(spacing: 12) {
        Button("Cancel", role: .cancel) {
          onCancel()
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Cancel adding school")

        Button("Proceed Anyway") {
          onProceed()
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .accessibilityLabel("Create duplicate school anyway")
      }
      .padding(.top, 8)
    }
    .padding(24)
  }
}
```

### 2.4: Integration in AddSchoolViewModel (1 hour)

Modify: `TheRecruitingCompass/Features/Schools/ViewModels/AddSchoolViewModel.swift`

Add state:
```swift
@Published var showDuplicateDialog = false
@Published var duplicateResult: DuplicateResult? = nil
```

Modify `submitSchool()`:
```swift
func submitSchool() async -> School? {
  // 1. Full validation (existing)
  formErrors = validateAllFields()
  guard !formErrors.hasErrors else {
    announceErrorsForAccessibility()
    return nil
  }

  // 2. Duplicate check (NEW)
  let request = SchoolCreateRequest.from(...)
  let duplicateCheck = DuplicateDetector.findDuplicate(
    in: schoolsService.getCachedSchools(),
    for: request
  )

  if duplicateCheck.isDuplicate {
    duplicateResult = duplicateCheck
    showDuplicateDialog = true
    return nil  // Wait for user decision
  }

  // 3. Create school (existing)
  return await createSchoolInternal(request: request)
}

// Extract creation logic for reuse after "Proceed Anyway"
private func createSchoolInternal(request: SchoolCreateRequest) async -> School? {
  isSubmitting = true
  submitError = nil
  defer { isSubmitting = false }

  do {
    let newSchool = try await schoolsService.createSchool(request: request)
    announcer.announceWithFeedback("School \(newSchool.name) added successfully", success: true)
    return newSchool
  } catch {
    submitError = "Failed to create school. Please try again."
    announcer.announceWithFeedback("Failed to create school", success: false)
    return nil
  }
}

func proceedDespiteDuplicate() async -> School? {
  guard let request = buildCurrentRequest() else { return nil }
  return await createSchoolInternal(request: request)
}
```

### 2.5: UI Integration (1 hour)

Modify: `TheRecruitingCompass/Features/Schools/Views/AddSchoolView.swift`

Add sheet:
```swift
.sheet(isPresented: $viewModel.showDuplicateDialog) {
  if let result = viewModel.duplicateResult,
     let duplicate = result.duplicate,
     let matchType = result.matchType {
    DuplicateSchoolDialog(
      duplicate: duplicate,
      matchType: matchType,
      onCancel: {
        viewModel.showDuplicateDialog = false
      },
      onProceed: {
        Task {
          viewModel.showDuplicateDialog = false
          if let newSchool = await viewModel.proceedDespiteDuplicate() {
            navigationPath.append(SchoolDestination.detail(newSchool.id))
          }
        }
      }
    )
  }
}
```

**Total Phase 2:** 6-8 hours, 10+ tests

---

## Phase 3: Auto-Filled Badge Polish (MEDIUM PRIORITY)

**Goal:** Fully integrate auto-filled badge display
**Time:** 2-3 hours

### 3.1: Badge Integration in SchoolFormView (1 hour)

Modify: `TheRecruitingCompass/Features/Schools/Components/SchoolFormView.swift`

Add badge to field labels:
```swift
private func labelWithBadge(
  _ label: String,
  field: AutoFillableField,
  isAutoFilled: Bool
) -> some View {
  HStack(spacing: 4) {
    Text(label)
    if isAutoFilled {
      AutoFilledBadge()
        .accessibilityLabel("\(label), auto-filled")
    }
  }
}
```

Update each auto-fillable field:
```swift
// Name
labelWithBadge("School Name", field: .name, isAutoFilled: formState.autoFilledFields.contains(.name))

// Location
labelWithBadge("Location", field: .location, isAutoFilled: formState.autoFilledFields.contains(.location))

// etc.
```

### 3.2: Badge Removal on Manual Edit (1 hour)

Add onChange handlers:
```swift
.onChange(of: formState.name) { oldValue, newValue in
  if oldValue != newValue && formState.autoFilledFields.contains(.name) {
    formState.autoFilledFields.remove(.name)
  }
}
```

**Total Phase 3:** 2-3 hours

---

## Phase 4: Documentation & Handoff (LOW PRIORITY)

**Goal:** Update docs and create handoff
**Time:** 2 hours

### 4.1: Update CLAUDE.md (30 min)

Add Add School feature section with:
- Feature overview
- Autocomplete usage
- NCAA database bundling
- College Scorecard API key config
- Duplicate detection flow

### 4.2: Create Handoff Doc (1 hour)

Create: `planning/HANDOFF_AddSchool_Complete.md`

Include:
- Feature summary
- Implementation details (Phases 1-4)
- Test coverage metrics
- Known limitations
- API key configuration
- Future enhancements

### 4.3: Update README (30 min)

Add setup instructions:
- College Scorecard API key configuration
- NCAA database bundling
- Environment variable setup

**Total Phase 4:** 2 hours

---

## Final Checklist (Spec Compliance)

### Functional Requirements (from Spec Section 1)
- [x] Toggle between autocomplete and manual entry
- [x] Search college database with minimum 3 characters
- [x] Autocomplete dropdown shows matching colleges
- [x] Select college auto-fills name, location, website
- [x] NCAA lookup auto-fills division and conference
- [x] College Scorecard enriches academic data
- [ ] Auto-filled fields show "(auto-filled)" badge (needs polish)
- [x] Selected college confirmation card
- [ ] Duplicate detection warns before creating (needs implementation)
- [ ] User can proceed anyway if intentional (needs implementation)
- [x] Form validation prevents invalid submission
- [x] Navigate to school detail on success

### Data Models (from Spec Section 3)
- [x] SchoolCreateInput
- [x] CollegeSearchResult
- [x] NcaaLookupResult
- [x] CollegeScorecardData
- [ ] DuplicateResult (needs implementation)
- [ ] DuplicateMatchType (needs implementation)
- [x] AddSchoolFormState
- [x] AutoFillableField

### UI/UX (from Spec Section 6)
- [x] Toggle Section
- [x] Selected College Card
- [x] Autocomplete Dropdown
- [x] Form Sections
- [x] College Scorecard Data Section
- [ ] Duplicate School Dialog (needs implementation)
- [ ] Auto-Filled Badges (needs integration polish)

### Testing (from Spec Section 9)
- [x] MVP tests (137 passing)
- [ ] Autocomplete tests (needs ~25 tests)
- [ ] NCAA tests (needs ~15 tests)
- [ ] Enrichment tests (needs ~15 tests)
- [ ] Duplicate detection tests (needs ~10 tests)
- [ ] Accessibility tests (needs ~15 tests)
- [ ] Integration tests (needs ~10 tests)

**Target:** 237+ total tests (137 MVP + 100 new)

---

## Timeline Summary

| Phase | Priority | Time | Status |
|-------|----------|------|--------|
| Phase 1: Testing (Phases 1-3) | HIGH | 8-10 hours | Not started |
| Phase 2: Duplicate Detection | HIGH | 6-8 hours | Not started |
| Phase 3: Auto-Filled Badges | MEDIUM | 2-3 hours | Not started |
| Phase 4: Documentation | LOW | 2 hours | Not started |
| **Total** | - | **18-23 hours** | **2-3 days** |

---

## Dependencies & Prerequisites

### Required Before Starting
1. **SchoolsService.getCachedSchools()** method exists
   - Needed for duplicate detection
   - Returns `[School]` from local cache/store

2. **College Scorecard API Key** configured
   - Autocomplete search requires valid API key
   - Environment variable or Supabase config

3. **Build passing** with Phases 1-3 changes
   - Verify no compilation errors
   - Verify no Swift 6 concurrency warnings

### Optional Enhancements (Future)
- Logo fetching from NCAA database
- NAIA/JUCO database support
- Offline mode with cached schools
- Advanced fuzzy matching (Levenshtein)

---

## Risk Assessment

### High Risk
- **Duplicate detection against large school lists**: May be slow if 1000+ schools cached
  - Mitigation: Index schools by name first letter

### Medium Risk
- **College Scorecard API rate limits**: 429 errors during heavy usage
  - Mitigation: Session caching already implemented

### Low Risk
- **Test coverage goal (90%+)**: May not reach 90% with 100 new tests
  - Mitigation: Focus on critical paths, edge cases

---

## Success Criteria

### Build & Test
- [ ] Build succeeds (0 errors, 0 warnings)
- [ ] 237+ tests passing (137 MVP + 100 new)
- [ ] 85%+ code coverage

### Functional
- [ ] All spec user flows working end-to-end
- [ ] Duplicate detection prevents accidental duplicates
- [ ] Auto-filled badges visible and remove on edit
- [ ] Accessibility: VoiceOver navigation works

### Documentation
- [ ] CLAUDE.md updated with Add School details
- [ ] Handoff doc created with setup instructions
- [ ] README updated with API key configuration

---

## Recommended Approach

**Day 1 (8 hours):**
- Morning: Phase 1.1-1.3 (NCAA, Scorecard, Autocomplete tests)
- Afternoon: Phase 1.4-1.6 (Enrichment, NCAA ViewModel, Accessibility tests)
- Evening: Verify all tests pass, commit Phases 1-3 with tests

**Day 2 (8 hours):**
- Morning: Phase 2.1-2.3 (Duplicate models, detector, dialog)
- Afternoon: Phase 2.4-2.5 (Integration, UI)
- Evening: Phase 3 (Auto-filled badge polish)

**Day 3 (4 hours):**
- Morning: Phase 4 (Documentation & handoff)
- Afternoon: Final verification, commit Phase 4, create PR

**Total:** 20 hours over 2.5 days

---

## Sign-Off

**Plan Author:** Claude Code
**Spec Reference:** `/Users/chrisandrikanich/Documents/Workspaces/Personal/TheRecruitingCompass/recruiting-compass-web/planning/iOS_SPEC_Phase3_AddSchool.md`
**Current Implementation:** 75% (Phases 1-3 uncommitted)
**Target:** 100% spec compliance
**Estimated Completion:** 2-3 days
**Ready for Implementation:** Yes
