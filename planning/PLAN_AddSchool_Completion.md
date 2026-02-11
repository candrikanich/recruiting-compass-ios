# Add School Feature - Completion Implementation Plan

**Project:** The Recruiting Compass iOS App
**Created:** February 11, 2026
**Status:** MVP Complete (40%) → Full Spec (100%)
**Estimated Time:** 3-4 days

---

## Current Status

### ✅ MVP Complete (Implemented)
- Manual entry form with 11 fields
- Real-time validation (9 validators)
- Data sanitization and preparation
- Supabase integration
- Form error handling
- Navigation on success
- 137 tests passing (85%+ coverage)
- Full accessibility support

### ❌ Fast-Follow Features (Not Implemented)
- Autocomplete mode with College Scorecard search
- NCAA database lookup for division/conference
- College Scorecard enrichment (academic data)
- Duplicate detection dialog
- Auto-filled badges
- Selected College Confirmation Card
- Logo fetching

---

## Implementation Phases

### Phase 1: NCAA Database Integration (8-10 hours)

**Goal:** Auto-populate division and conference when school name is entered

#### Tasks

##### 1.1: Bundle NCAA Database (2 hours)
- [ ] Export web NCAA data to JSON files
  - Extract `DIVISION_SCHOOLS.D1`, `.D2`, `.D3` from web codebase
  - Convert to `ncaa_d1.json`, `ncaa_d2.json`, `ncaa_d3.json`
  - Add to iOS app bundle as resources
- [ ] Create `NcaaSchoolInfo` model
  ```swift
  struct NcaaSchoolInfo: Codable {
    let name: String
    let conference: String
  }
  ```

##### 1.2: NcaaDatabase Service (3 hours)
- [ ] Create `TheRecruitingCompass/Features/Schools/Services/NcaaDatabase.swift`
- [ ] Implement resource loading
  ```swift
  final class NcaaDatabase {
    static let shared = NcaaDatabase()
    private let d1Schools: [NcaaSchoolInfo]
    private let d2Schools: [NcaaSchoolInfo]
    private let d3Schools: [NcaaSchoolInfo]

    func lookup(schoolName: String) -> NcaaLookupResult?
  }
  ```
- [ ] Implement school name normalization
  - Strip "University", "College", "The" prefixes
  - Lowercase, trim whitespace
  - Remove punctuation
- [ ] Implement fuzzy matching
  - Exact match (priority 1)
  - Partial match (>8 chars, priority 2)
  - Levenshtein distance ≤ 2 (priority 3)

##### 1.3: Session Caching (1 hour)
- [ ] Add `@Published var ncaaLookupCache: [String: NcaaLookupResult]` to AddSchoolViewModel
- [ ] Cache successful lookups by normalized name
- [ ] Return cached result before searching database

##### 1.4: Integration (2 hours)
- [ ] Add NCAA lookup to `AddSchoolViewModel`
  ```swift
  func performNcaaLookup(for schoolName: String) {
    guard let result = NcaaDatabase.shared.lookup(schoolName: schoolName) else {
      logger.debug("No NCAA match for: \(schoolName)")
      return
    }

    formState.division = result.division
    formState.conference = result.conference
    formState.autoFilledFields.insert(.division)
    formState.autoFilledFields.insert(.conference)
  }
  ```
- [ ] Trigger lookup on school name blur (only if division is nil)
- [ ] Show auto-filled badges for division and conference

##### 1.5: Testing (2 hours)
- [ ] Unit tests for `NcaaDatabase`
  - Exact match
  - Partial match
  - Fuzzy match (Levenshtein)
  - No match
- [ ] ViewModel tests for NCAA lookup integration
  - Successful lookup updates formState
  - Failed lookup is silent
  - Cache hit prevents duplicate lookup
- [ ] UI tests for auto-filled badges

**Deliverable:** NCAA division/conference auto-populated when user types school name

---

### Phase 2: College Scorecard Autocomplete (10-12 hours)

**Goal:** Enable database search with autocomplete dropdown

#### Tasks

##### 2.1: Autocomplete Search State (1 hour)
- [ ] Add to `AddSchoolViewModel`:
  ```swift
  @Published var searchQuery: String = ""
  @Published var searchResults: [CollegeSearchResult] = []
  @Published var isSearching = false
  @Published var selectedCollege: CollegeSearchResult? = nil
  @Published var searchError: String? = nil
  ```
- [ ] Add 300ms debounce using `Combine`
  ```swift
  private var searchCancellable: AnyCancellable?

  func setupSearchDebounce() {
    searchCancellable = $searchQuery
      .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
      .removeDuplicates()
      .sink { [weak self] query in
        Task { await self?.performSearch(query: query) }
      }
  }
  ```

##### 2.2: College Search Result Model (1 hour)
- [ ] Create `TheRecruitingCompass/Features/Schools/Models/CollegeSearchResult.swift`
  ```swift
  struct CollegeSearchResult: Identifiable, Codable {
    let id: String
    let name: String
    let city: String
    let state: String

    var location: String {
      "\(city), \(state)"
    }

    var website: String?
  }
  ```

##### 2.3: Autocomplete API Integration (3 hours)
- [ ] Update `CollegeScorecardService` with search method
  ```swift
  func searchColleges(query: String) async throws -> [CollegeSearchResult] {
    // GET https://api.data.gov/ed/collegescorecard/v1/schools
    //   ?api_key={key}
    //   &school.name={query}
    //   &per_page=10
  }
  ```
- [ ] Add error handling:
  - API key missing → throw `.apiKeyMissing`
  - Query < 3 chars → throw `.nameTooShort`
  - Rate limited (429) → throw `.rateLimited`
  - Network error → throw `.networkError`
- [ ] Add response parsing from College Scorecard API format

##### 2.4: Autocomplete Dropdown UI (4 hours)
- [ ] Create `TheRecruitingCompass/Features/Schools/Components/SchoolAutocompleteDropdown.swift`
  ```swift
  struct SchoolAutocompleteDropdown: View {
    let results: [CollegeSearchResult]
    let isLoading: Bool
    let error: String?
    let onSelect: (CollegeSearchResult) -> Void

    var body: some View {
      // List overlay below search field
      // Show loading spinner
      // Show "No results" if empty
      // Show error banner if error
    }
  }
  ```
- [ ] Add to `AddSchoolView` autocomplete section
  ```swift
  if viewModel.formState.isAutocompleteEnabled {
    VStack {
      TextField("Search colleges...", text: $viewModel.searchQuery)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.words)

      if !viewModel.searchResults.isEmpty || viewModel.isSearching {
        SchoolAutocompleteDropdown(
          results: viewModel.searchResults,
          isLoading: viewModel.isSearching,
          error: viewModel.searchError,
          onSelect: viewModel.selectCollege
        )
      }
    }
  }
  ```

##### 2.5: Selection Handler (2 hours)
- [ ] Implement `selectCollege()` in ViewModel
  ```swift
  func selectCollege(_ college: CollegeSearchResult) async {
    selectedCollege = college

    // Auto-fill basic fields
    formState.name = college.name
    formState.city = college.city
    formState.state = college.state
    formState.location = college.location
    formState.website = college.website ?? ""

    // Mark as auto-filled
    formState.autoFilledFields = [.name, .location, .website]

    // Trigger NCAA lookup
    performNcaaLookup(for: college.name)

    // Trigger College Scorecard enrichment
    await performScorecardEnrichment(collegeId: college.id)
  }
  ```
- [ ] Add clear selection handler
  ```swift
  func clearSelection() {
    selectedCollege = nil
    formState.autoFilledFields.removeAll()
    // Optionally clear auto-filled fields
  }
  ```

##### 2.6: Toggle Integration (1 hour)
- [ ] Enable autocomplete toggle in `AddSchoolView`
  ```swift
  Toggle("Search college database", isOn: $viewModel.formState.isAutocompleteEnabled)
    .disabled(false) // Remove MVP disable
  ```
- [ ] Add state management for toggle
  - When toggled ON: Show autocomplete search, hide manual name field
  - When toggled OFF: Hide autocomplete, show manual name field
  - When toggled OFF with selection: Preserve auto-filled data

**Deliverable:** Functional autocomplete search with dropdown and college selection

---

### Phase 3: College Scorecard Enrichment (6-8 hours)

**Goal:** Auto-populate academic data (student size, admission rate, tuition, coordinates)

#### Tasks

##### 3.1: Enrichment State (1 hour)
- [ ] Add to `AddSchoolViewModel`:
  ```swift
  @Published var scorecardData: CollegeScorecardData? = nil
  @Published var isEnrichmentLoading = false
  @Published var enrichmentError: String? = nil
  ```

##### 3.2: College Scorecard Lookup (2 hours)
- [ ] Update `CollegeScorecardService.lookupCollege()` to return full data
  - Already implemented, just needs integration
- [ ] Add session caching
  ```swift
  private var scorecardCache: [String: CollegeScorecardData] = [:]
  ```

##### 3.3: Enrichment Integration (2 hours)
- [ ] Add `performScorecardEnrichment()` to ViewModel
  ```swift
  func performScorecardEnrichment(collegeId: String) async {
    isEnrichmentLoading = true
    defer { isEnrichmentLoading = false }

    do {
      scorecardData = try await collegeScorecardService.lookupCollege(name: selectedCollege?.name ?? "")
      enrichmentError = nil
    } catch {
      logger.error("Scorecard enrichment failed: \(error)")
      enrichmentError = nil // Silent failure per spec
    }
  }
  ```
- [ ] Trigger on college selection
- [ ] Store `scorecardData` for inclusion in submission

##### 3.4: Selected College Confirmation Card (2 hours)
- [ ] Create `TheRecruitingCompass/Features/Schools/Components/SelectedCollegeCard.swift`
  ```swift
  struct SelectedCollegeCard: View {
    let college: CollegeSearchResult
    let isLoading: Bool
    let onClear: () -> Void

    var body: some View {
      HStack {
        VStack(alignment: .leading) {
          Text("✅ Selected: \(college.name)")
            .font(.headline)
          Text(college.location)
            .font(.subheadline)

          if isLoading {
            HStack {
              ProgressView()
              Text("Fetching college data...")
            }
          } else {
            Text("✓ College data and map coordinates loaded")
              .foregroundStyle(.green)
          }
        }

        Spacer()

        Button("Clear") {
          onClear()
        }
      }
      .padding()
      .background(Color.green.opacity(0.1))
      .border(Color.green)
    }
  }
  ```

##### 3.5: College Scorecard Data Section (1 hour)
- [ ] Create `TheRecruitingCompass/Features/Schools/Components/CollegeScorecardDataSection.swift`
  - Already exists as `CollegeDataSection.swift`
  - Update to show in AddSchoolView when `scorecardData != nil`

**Deliverable:** Academic data auto-populated and displayed for selected colleges

---

### Phase 4: Duplicate Detection (6-8 hours)

**Goal:** Warn user before creating duplicate schools

#### Tasks

##### 4.1: Duplicate Detection Models (1 hour)
- [ ] Create `TheRecruitingCompass/Features/Schools/Models/DuplicateResult.swift`
  ```swift
  struct DuplicateResult {
    let duplicate: School?
    let matchType: DuplicateMatchType?
  }

  enum DuplicateMatchType: String {
    case name
    case domain
    case ncaaId

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

##### 4.2: Duplicate Detector Logic (3 hours)
- [ ] Create `TheRecruitingCompass/Features/Schools/Services/DuplicateDetector.swift`
  ```swift
  struct DuplicateDetector {
    static func findDuplicate(
      in existingSchools: [School],
      for input: SchoolCreateRequest
    ) -> DuplicateResult {
      // 1. Name match (case-insensitive exact)
      // 2. Domain match (extract hostname, compare)
      // 3. NCAA ID match (if available)
    }

    private static func extractDomain(from urlString: String) -> String? {
      // Parse URL, extract host, strip "www."
    }
  }
  ```
- [ ] Add unit tests
  - Exact name match
  - Domain match
  - No match
  - Multiple match types (highest priority wins)

##### 4.3: Duplicate Check Integration (1 hour)
- [ ] Add duplicate check to `submitSchool()` in ViewModel
  ```swift
  func submitSchool() async -> School? {
    // 1. Validation (existing)

    // 2. Duplicate check
    let duplicateCheck = DuplicateDetector.findDuplicate(
      in: schoolsService.getCachedSchools(),
      for: buildCreateRequest()
    )

    if duplicateCheck.duplicate != nil {
      duplicateResult = duplicateCheck
      showDuplicateDialog = true
      return nil  // Wait for user decision
    }

    // 3. Create school (existing)
  }
  ```

##### 4.4: Duplicate Dialog UI (2 hours)
- [ ] Create `TheRecruitingCompass/Features/Schools/Components/DuplicateSchoolDialog.swift`
  ```swift
  struct DuplicateSchoolDialog: View {
    let duplicate: School
    let matchType: DuplicateMatchType
    let onCancel: () -> Void
    let onProceed: () -> Void

    var body: some View {
      VStack {
        Text("⚠️ Duplicate School Detected")
          .font(.headline)

        Text("A school already exists that matches your entry...")

        HStack {
          Text("Match Type:")
          Text(matchType.displayLabel)
            .padding(4)
            .background(matchType.badgeColor.opacity(0.2))
        }

        VStack {
          Text("Existing School")
            .font(.caption)
          Text(duplicate.name)
          Text("Division: \(duplicate.division?.displayName ?? "N/A") - \(duplicate.conference ?? "N/A")")
          Text("Location: \(duplicate.location ?? "N/A")")
        }
        .padding()
        .border(Color.gray)

        HStack {
          Button("Cancel", role: .cancel, action: onCancel)
          Button("Proceed Anyway", action: onProceed)
        }
      }
      .padding()
    }
  }
  ```
- [ ] Integrate with `.sheet()` modifier in AddSchoolView
  ```swift
  .sheet(isPresented: $viewModel.showDuplicateDialog) {
    if let result = viewModel.duplicateResult {
      DuplicateSchoolDialog(
        duplicate: result.duplicate!,
        matchType: result.matchType!,
        onCancel: { viewModel.showDuplicateDialog = false },
        onProceed: {
          Task {
            viewModel.showDuplicateDialog = false
            await viewModel.createSchoolIgnoringDuplicate()
          }
        }
      )
    }
  }
  ```

##### 4.5: Testing (2 hours)
- [ ] Unit tests for `DuplicateDetector`
- [ ] ViewModel tests for duplicate detection flow
- [ ] UI tests for duplicate dialog

**Deliverable:** Duplicate detection with warning dialog before creation

---

### Phase 5: Auto-Filled Badges & Polish (4-6 hours)

**Goal:** Visual indicators for auto-populated fields

#### Tasks

##### 5.1: Auto-Filled Badge Logic (2 hours)
- [ ] Update `SchoolFormState.autoFilledFields` logic
  - Track when NCAA lookup fills division/conference
  - Track when autocomplete fills name/location/website
- [ ] Remove auto-filled badge when user manually edits field
  ```swift
  func handleFieldEdit(_ field: AutoFillableField) {
    formState.autoFilledFields.remove(field)
  }
  ```

##### 5.2: Badge Display (1 hour)
- [ ] Update `AutoFilledBadge.swift` to show conditionally
  ```swift
  struct AutoFilledBadge: View {
    let isAutoFilled: Bool

    var body: some View {
      if isAutoFilled {
        Text("(auto-filled)")
          .font(.caption)
          .foregroundStyle(.blue)
          .accessibilityLabel("auto-filled")
      }
    }
  }
  ```
- [ ] Add to each auto-fillable field label in `SchoolFormView`

##### 5.3: Error Handling Polish (2 hours)
- [ ] Add offline detection
  ```swift
  var isOffline: Bool {
    // Use Network.framework NWPathMonitor
  }
  ```
- [ ] Show offline banner if network unavailable
- [ ] Handle College Scorecard rate limiting (429)
  - Show "Too many requests" message
  - Disable autocomplete temporarily
- [ ] Handle API key missing gracefully
  - Show "College search not configured" in footer
  - Keep toggle visible but disabled

##### 5.4: Loading States (1 hour)
- [ ] Add inline spinner to autocomplete dropdown during search
- [ ] Add "Fetching college data..." to Selected College Card
- [ ] Update submit button text: "Adding..." during submission

**Deliverable:** Polished UI with auto-filled badges and comprehensive error handling

---

### Phase 6: Testing & Documentation (4-6 hours)

**Goal:** Comprehensive test coverage and updated documentation

#### Tasks

##### 6.1: Unit Tests (2 hours)
- [ ] NcaaDatabase tests (15 tests)
- [ ] DuplicateDetector tests (10 tests)
- [ ] CollegeScorecardService autocomplete tests (8 tests)
- [ ] ViewModel autocomplete flow tests (20 tests)

##### 6.2: Integration Tests (1 hour)
- [ ] End-to-end autocomplete → enrichment → submission
- [ ] Duplicate detection flow
- [ ] Toggle between manual/autocomplete modes

##### 6.3: Accessibility Tests (1 hour)
- [ ] Autocomplete dropdown VoiceOver labels
- [ ] Selected College Card accessibility
- [ ] Duplicate dialog accessibility
- [ ] Auto-filled badge announcements

##### 6.4: Documentation (2 hours)
- [ ] Update `CLAUDE.md` with Add School feature details
- [ ] Create `HANDOFF_AddSchool_Complete.md`
- [ ] Update README with autocomplete setup instructions
- [ ] Document College Scorecard API key configuration

**Deliverable:** 200+ tests passing, comprehensive documentation

---

## File Structure (New Files)

```
TheRecruitingCompass/Features/Schools/
├── Components/
│   ├── SchoolAutocompleteDropdown.swift       [NEW]
│   ├── SelectedCollegeCard.swift              [NEW]
│   └── DuplicateSchoolDialog.swift            [NEW]
├── Models/
│   ├── CollegeSearchResult.swift              [NEW]
│   ├── DuplicateResult.swift                  [NEW]
│   └── DuplicateMatchType.swift               [NEW]
├── Services/
│   ├── NcaaDatabase.swift                     [NEW]
│   ├── DuplicateDetector.swift                [NEW]
│   └── CollegeScorecardService.swift          [MODIFY]
└── Resources/
    ├── ncaa_d1.json                           [NEW]
    ├── ncaa_d2.json                           [NEW]
    └── ncaa_d3.json                           [NEW]

TheRecruitingCompassTests/Features/Schools/
├── Services/
│   ├── NcaaDatabaseTests.swift                [NEW]
│   └── DuplicateDetectorTests.swift           [NEW]
└── Components/
    └── SchoolAutocompleteDropdownTests.swift  [NEW]
```

---

## Success Criteria

### Functional Requirements
- [ ] User can toggle between autocomplete and manual entry
- [ ] Typing 3+ chars triggers College Scorecard search
- [ ] Search results display in dropdown with name + location
- [ ] Selecting a college auto-fills: name, location, website
- [ ] NCAA lookup auto-fills division and conference (when found)
- [ ] College Scorecard enriches with academic data
- [ ] Auto-filled fields show blue "(auto-filled)" badge
- [ ] User can clear selection and start over
- [ ] Duplicate detection warns before creating duplicate
- [ ] User can proceed anyway if intentional
- [ ] Form submission includes College Scorecard data in `academic_info`

### Technical Requirements
- [ ] Build succeeds with 0 errors, 0 warnings
- [ ] 200+ tests passing (90%+ coverage)
- [ ] All new code follows MVVM architecture
- [ ] Protocol-based dependency injection for testability
- [ ] Full accessibility (VoiceOver labels, hints, Dynamic Type)
- [ ] Comprehensive error handling (network, API, validation)
- [ ] Session caching for NCAA and Scorecard lookups
- [ ] 300ms debounce on autocomplete search

### Non-Functional Requirements
- [ ] Autocomplete search responds in < 1 second
- [ ] NCAA lookup completes in < 100ms (local)
- [ ] Form submission completes in < 3 seconds
- [ ] No memory leaks during enrichment
- [ ] Keyboard doesn't obscure form fields
- [ ] Works on iPhone and iPad (responsive layout)

---

## Dependencies & Configuration

### NCAA Database Setup
1. Extract NCAA data from web codebase: `/composables/ncaaDatabase.ts`
2. Convert to JSON files (Python script recommended)
3. Add to iOS project: `Supporting Files/Resources/`

### College Scorecard API Key
- **Web config**: `collegeScorecardApiKey` in runtime config
- **iOS config**:
  - Option 1: Environment variable `COLLEGE_SCORECARD_API_KEY`
  - Option 2: Supabase config table (fetch on app launch)
  - Option 3: Bundled in `Info.plist` (encrypted)

### Cached Schools List
- Requires `SchoolsService.getCachedSchools()` method
- AddSchoolViewModel must have access to existing schools for duplicate detection

---

## Risk Assessment

### High Risk
- **College Scorecard API availability**: Web implementation has fallback to manual entry
- **NCAA database size**: JSON files may be large (check bundle size impact)

### Medium Risk
- **Fuzzy matching performance**: Levenshtein distance on 1000+ schools may be slow
- **Duplicate detection edge cases**: Same name, different programs (intentional duplicates)

### Low Risk
- **API key security**: Use environment variables or secure storage
- **Network errors**: Comprehensive error handling already planned

---

## Timeline Estimate

| Phase | Time | Dependencies |
|-------|------|--------------|
| Phase 1: NCAA Database | 8-10 hours | Export web data |
| Phase 2: Autocomplete | 10-12 hours | College Scorecard API key |
| Phase 3: Enrichment | 6-8 hours | Phase 2 complete |
| Phase 4: Duplicate Detection | 6-8 hours | Cached schools list |
| Phase 5: Polish | 4-6 hours | All phases complete |
| Phase 6: Testing & Docs | 4-6 hours | All phases complete |
| **Total** | **38-50 hours** | **3-4 days** |

---

## Notes

### MVP vs Full Spec Tradeoff
The current MVP (manual entry only) is **production-ready** and covers the core use case. The fast-follow features (autocomplete, enrichment, duplicate detection) are **nice-to-have enhancements** that improve UX but are not blocking for users to add schools.

### Recommended Approach
1. **Ship MVP now** (manual entry is fully functional)
2. **Phase 1-2 next** (autocomplete + NCAA lookup provide biggest UX win)
3. **Phase 3-4 later** (enrichment + duplicate detection are polish)
4. **Phase 5-6 continuous** (polish and testing ongoing)

### Alternative: Simplified Fast-Follow
If time is limited, consider implementing **Phase 1 only** (NCAA database lookup):
- Users type school name manually
- System auto-fills division and conference
- No College Scorecard dependency
- No duplicate detection complexity
- Still a significant UX improvement over pure manual entry

---

## Sign-Off

**Plan Author:** Claude Code
**Plan Reviewed:** Pending
**Approved for Implementation:** Pending
**Estimated Completion:** 3-4 days after approval
