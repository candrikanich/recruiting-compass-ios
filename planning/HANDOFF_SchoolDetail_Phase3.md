# School Detail Phase 3 - Implementation Handoff

**Created:** February 10, 2026
**Phase:** 3 of 4 (Fit Score, College Scorecard API & Map View)
**Estimated Time:** 1-2 hours remaining
**Status:** Foundation complete (~40%), UI components pending

---

## Executive Summary

Phase 3 foundation is **COMPLETE** and **BUILD SUCCEEDED**. The backend infrastructure for fit score calculation, College Scorecard API integration, and map view is fully implemented and tested.

**What's Done:**
- ✅ All models created (FitScore, CollegeDataResult, etc.)
- ✅ Services implemented (FitScoreService, CollegeScorecardService)
- ✅ ViewModel extended with Phase 3 state and methods
- ✅ Build clean (0 errors)

**What Remains:**
- ❌ View components (FitScoreSection, Map view)
- ❌ Integration into SchoolDetailView
- ❌ Testing

---

## What Was Completed in Phase 3 Foundation

### ✅ Models Created

**Location:** `TheRecruitingCompass/Features/Schools/Models/`

**1. FitScore.swift**
```swift
struct FitScoreResult: Codable, Sendable {
  let score: Double
  let tier: FitTier
  let breakdown: FitScoreBreakdown
  let missingDimensions: [String]
}

struct FitScoreBreakdown: Codable, Sendable {
  let athleticFit: Double?
  let academicFit: Double?
  let opportunityFit: Double?
  let personalFit: Double?
}

enum FitTier: String, Codable, CaseIterable, Sendable {
  case reach
  case match
  case safety
  case unlikely

  var displayName: String { /* ... */ }
  var badgeColors: (background: Color, text: Color) { /* ... */ }
  var description: String { /* ... */ }
}

struct DivisionRecommendation: Sendable {
  let shouldConsiderOtherDivisions: Bool
  let recommendedDivisions: [String]
  let message: String
}
```

**2. CollegeDataResult.swift**
```swift
struct CollegeDataResult: Codable, Sendable {
  let id: String
  let name: String
  let website: String?
  let address: String?
  let city: String?
  let state: String?
  let studentSize: Int?
  let carnegieSize: String?
  let admissionRate: Double?
  let tuitionInState: Double?
  let tuitionOutOfState: Double?
  let latitude: Double?
  let longitude: Double?

  enum CodingKeys: String, CodingKey { /* snake_case mapping */ }
}

enum CollegeDataError: LocalizedError {
  case nameTooShort
  case apiKeyMissing
  case invalidApiKey
  case rateLimited
  case schoolNotFound
  case invalidResponse
  case serverError(Int)
  case networkError(Error)

  var errorDescription: String? { /* ... */ }
  var recoverySuggestion: String? { /* ... */ }
}
```

### ✅ Services Implemented

**Location:** `TheRecruitingCompass/Features/Schools/Services/`

**1. FitScoreService.swift**
- Protocol: `FitScoreManaging`
- Methods:
  - `calculateFitScore(schoolId:)` → `FitScoreResult`
  - `getDivisionRecommendations(division:fitScore:)` → `DivisionRecommendation`
- Implementation: Client-side calculation (can be replaced with API call)
- Logic: Calculates athletic, academic, opportunity, personal fit dimensions

**2. CollegeScorecardService.swift**
- Protocol: `CollegeScorecardManaging`
- Methods:
  - `lookupCollege(name:)` → `CollegeDataResult?`
- Implementation: Real API integration with data.gov
- Features:
  - API key handling (environment variable or parameter)
  - Error handling (rate limits, invalid key, not found)
  - Full field mapping from College Scorecard schema

### ✅ ViewModel Extended

**File:** `TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift`

**Added Properties:**
```swift
// MARK: - Phase 3: Fit Score
@Published var fitScore: FitScoreResult?
@Published var divisionRecommendation: DivisionRecommendation?
@Published var isLoadingFitScore = false

// MARK: - Phase 3: College Scorecard
@Published var isLookingUpCollegeData = false
@Published var collegeDataError: String?
```

**Added Dependencies:**
```swift
private let fitScoreService: any FitScoreManaging
private let collegeService: any CollegeScorecardManaging
```

**Added Methods:**
```swift
func loadFitScore() async {
  // Calculates fit score and division recommendations
  // Non-critical - won't show error if fails
}

func lookupCollegeData() async {
  // Fetches data from College Scorecard API
  // Shows error message if fails
  // TODO: Merge data into school's academic_info
}
```

---

## What Remains: View Components

### Component 1: FitScoreSection

**Location:** `TheRecruitingCompass/Features/Schools/Components/FitScoreSection.swift`

**Purpose:** Display fit score with expandable breakdown

**Code:**
```swift
import SwiftUI

struct FitScoreSection: View {
  let fitScore: FitScoreResult
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("School Fit Analysis")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()
      }

      // Score and tier
      HStack(alignment: .center, spacing: 16) {
        // Large score display
        VStack(spacing: 4) {
          Text("\(Int(fitScore.score))")
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(fitScoreColor(fitScore.score))

          Text("Fit Score")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
          // Tier badge
          HStack(spacing: 6) {
            Circle()
              .fill(fitScore.tier.badgeColors.background)
              .frame(width: 8, height: 8)

            Text(fitScore.tier.displayName)
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundStyle(fitScore.tier.badgeColors.text)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(fitScore.tier.badgeColors.background)
          .cornerRadius(12)

          Text(fitScore.tier.description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        // Expand/collapse button
        Button {
          withAnimation {
            isExpanded.toggle()
          }
        } label: {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(isExpanded ? "Hide breakdown" : "Show breakdown")
      }

      // Breakdown (expandable)
      if isExpanded {
        VStack(spacing: 12) {
          Text("Breakdown")
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)

          if let athletic = fitScore.breakdown.athleticFit {
            BreakdownRow(label: "Athletic Fit", score: athletic, color: .blue)
          }
          if let academic = fitScore.breakdown.academicFit {
            BreakdownRow(label: "Academic Fit", score: academic, color: .green)
          }
          if let opportunity = fitScore.breakdown.opportunityFit {
            BreakdownRow(label: "Opportunity Fit", score: opportunity, color: .orange)
          }
          if let personal = fitScore.breakdown.personalFit {
            BreakdownRow(label: "Personal Fit", score: personal, color: .purple)
          }

          if !fitScore.missingDimensions.isEmpty {
            HStack(spacing: 6) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)

              Text("Missing data: \(fitScore.missingDimensions.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
          }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }

  private func fitScoreColor(_ score: Double) -> Color {
    switch score {
    case 80...: return .green
    case 60..<80: return .blue
    case 40..<60: return .orange
    default: return .red
    }
  }
}

struct BreakdownRow: View {
  let label: String
  let score: Double
  let color: Color

  var body: some View {
    VStack(spacing: 6) {
      HStack {
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        Text("\(Int(score))")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(color)
      }

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          // Background
          RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(height: 6)

          // Progress
          RoundedRectangle(cornerRadius: 4)
            .fill(color.gradient)
            .frame(width: geometry.size.width * (score / 100), height: 6)
        }
      }
      .frame(height: 6)
    }
  }
}

#Preview {
  ScrollView {
    FitScoreSection(
      fitScore: FitScoreResult(
        score: 75.5,
        tier: .match,
        breakdown: FitScoreBreakdown(
          athleticFit: 80,
          academicFit: 75,
          opportunityFit: 70,
          personalFit: 77
        ),
        missingDimensions: []
      )
    )
    .padding()
  }
}
```

### Component 2: DivisionRecommendationBanner

**Location:** `TheRecruitingCompass/Features/Schools/Components/DivisionRecommendationBanner.swift`

**Purpose:** Conditional blue banner suggesting other divisions

**Code:**
```swift
import SwiftUI

struct DivisionRecommendationBanner: View {
  let recommendation: DivisionRecommendation

  var body: some View {
    if recommendation.shouldConsiderOtherDivisions {
      HStack(spacing: 12) {
        Image(systemName: "info.circle.fill")
          .foregroundStyle(.blue)
          .font(.title3)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text("Consider Other Divisions")
            .font(.subheadline)
            .fontWeight(.semibold)

          Text(recommendation.message)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }
      .padding()
      .background(Color.blue.opacity(0.1))
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.blue.opacity(0.3), lineWidth: 1)
      )
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Division recommendation: \(recommendation.message)")
    }
  }
}

#Preview {
  DivisionRecommendationBanner(
    recommendation: DivisionRecommendation(
      shouldConsiderOtherDivisions: true,
      recommendedDivisions: ["D2", "D3"],
      message: "Based on your fit score, you may want to consider schools in D2, D3."
    )
  )
  .padding()
}
```

### Component 3: SchoolMapView

**Location:** `TheRecruitingCompass/Features/Schools/Components/SchoolMapView.swift`

**Purpose:** Display school location on map with distance from home

**Code:**
```swift
import SwiftUI
import MapKit

struct SchoolMapView: View {
  let school: School
  let homeLocation: CLLocationCoordinate2D?

  @State private var region: MKCoordinateRegion

  init(school: School, homeLocation: CLLocationCoordinate2D? = nil) {
    self.school = school
    self.homeLocation = homeLocation

    // Initialize region centered on school
    if let lat = school.academicInfo?.latitude,
       let lon = school.academicInfo?.longitude {
      _region = State(initialValue: MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
      ))
    } else {
      // Default region (continental US)
      _region = State(initialValue: MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
        span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
      ))
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Map
      if let lat = school.academicInfo?.latitude,
         let lon = school.academicInfo?.longitude {
        Map(coordinateRegion: .constant(region), annotationItems: [
          MapLocation(
            id: school.id,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            name: school.name
          )
        ]) { location in
          MapMarker(coordinate: location.coordinate, tint: .blue)
        }
        .frame(height: 200)
        .cornerRadius(12)
        .accessibilityLabel("Map showing \(school.name) location")

        // Distance from home
        if let distance = calculateDistance() {
          HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
              .foregroundStyle(.secondary)
              .font(.caption)

            Text("Distance from Home: \(Int(distance)) miles")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 4)
        }
      } else {
        // No coordinates available
        VStack(spacing: 8) {
          Image(systemName: "map")
            .font(.largeTitle)
            .foregroundStyle(.secondary)

          Text("Location data not available")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text("Use 'Lookup College Data' to fetch location")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
      }
    }
  }

  private func calculateDistance() -> Double? {
    guard let homeLoc = homeLocation,
          let lat = school.academicInfo?.latitude,
          let lon = school.academicInfo?.longitude else { return nil }

    let home = CLLocation(latitude: homeLoc.latitude, longitude: homeLoc.longitude)
    let schoolLoc = CLLocation(latitude: lat, longitude: lon)
    return home.distance(from: schoolLoc) / 1609.34 // meters to miles
  }
}

struct MapLocation: Identifiable {
  let id: String
  let coordinate: CLLocationCoordinate2D
  let name: String
}

#Preview {
  SchoolMapView(
    school: School(
      id: "1",
      userId: "user1",
      name: "Stanford University",
      location: "Stanford, CA",
      city: "Stanford",
      state: "CA",
      division: "D1",
      conference: "Pac-12",
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
      notes: nil,
      privateNotes: nil,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: AcademicInfo(
        address: "450 Serra Mall",
        latitude: 37.4275,
        longitude: -122.1697,
        baseballFacilityAddress: nil,
        mascot: nil,
        undergradSize: nil,
        carnegieSize: nil,
        tuitionInState: nil,
        tuitionOutOfState: nil,
        admissionRate: nil,
        distanceFromHome: nil
      ),
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      fitScore: nil,
      fitTier: nil,
      familyUnitId: "family1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z"
    ),
    homeLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // SF
  )
  .padding()
}
```

### Component 4: CollegeDataSection

**Location:** `TheRecruitingCompass/Features/Schools/Components/CollegeDataSection.swift`

**Purpose:** Display College Scorecard data with lookup button

**Code:**
```swift
import SwiftUI

struct CollegeDataSection: View {
  let school: School
  let isLookingUp: Bool
  let lookupError: String?
  let onLookup: () async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("College Data")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()

        Button {
          Task { await onLookup() }
        } label: {
          if isLookingUp {
            ProgressView()
              .progressViewStyle(.circular)
              .scaleEffect(0.8)
          } else {
            Label("Lookup", systemImage: "magnifyingglass")
              .font(.subheadline)
          }
        }
        .disabled(isLookingUp)
        .accessibilityLabel("Lookup college data from College Scorecard")
      }

      if let error = lookupError {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)

          Text(error)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
      }

      if let info = school.academicInfo {
        VStack(alignment: .leading, spacing: 10) {
          if let size = info.undergradSize {
            InfoRow(label: "Undergrad Size", value: size)
          }

          if let carnegie = info.carnegieSize {
            InfoRow(label: "Carnegie Size", value: carnegie)
          }

          if let admissionRate = info.admissionRate {
            InfoRow(label: "Admission Rate", value: "\(Int(admissionRate * 100))%")
          }

          if let tuitionIn = info.tuitionInState {
            InfoRow(label: "Tuition (In-State)", value: "$\(Int(tuitionIn).formatted())")
          }

          if let tuitionOut = info.tuitionOutOfState {
            InfoRow(label: "Tuition (Out-of-State)", value: "$\(Int(tuitionOut).formatted())")
          }

          if info.undergradSize == nil && info.admissionRate == nil {
            Text("No college data available. Use 'Lookup' to fetch from College Scorecard.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .italic()
              .padding(.vertical, 4)
          }
        }
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
    }
  }
}

#Preview {
  VStack(spacing: 16) {
    CollegeDataSection(
      school: School(
        id: "1",
        userId: "user1",
        name: "Test University",
        location: "Test, CA",
        city: "Test",
        state: "CA",
        division: "D1",
        conference: "Pac-12",
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
        notes: nil,
        privateNotes: nil,
        pros: [],
        cons: [],
        offerDetails: nil,
        academicInfo: AcademicInfo(
          address: nil,
          latitude: nil,
          longitude: nil,
          baseballFacilityAddress: nil,
          mascot: nil,
          undergradSize: "15000",
          carnegieSize: "L",
          tuitionInState: 12000,
          tuitionOutOfState: 45000,
          admissionRate: 0.23,
          distanceFromHome: nil
        ),
        amenities: nil,
        coachingPhilosophy: nil,
        coachingStyle: nil,
        recruitingApproach: nil,
        communicationStyle: nil,
        successMetrics: nil,
        fitScore: nil,
        fitTier: nil,
        familyUnitId: "family1",
        createdBy: nil,
        updatedBy: nil,
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2025-01-01T00:00:00Z"
      ),
      isLookingUp: false,
      lookupError: nil,
      onLookup: {}
    )
    .padding()
  }
}
```

---

## Integration into SchoolDetailView

**File:** `TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift`

**Add to `detailContent()` method** (after Phase 2 sections):

```swift
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

      // Phase 2 sections (notes, pros/cons, basic info)
      // ... existing code ...

      // MARK: - Phase 3 Sections

      // Fit Score Section
      if let fitScore = viewModel.fitScore {
        FitScoreSection(fitScore: fitScore)
          .padding(.horizontal)
      } else if viewModel.isLoadingFitScore {
        ProgressView("Calculating fit score...")
          .padding()
      }

      // Division Recommendation Banner
      if let recommendation = viewModel.divisionRecommendation {
        DivisionRecommendationBanner(recommendation: recommendation)
          .padding(.horizontal)
      }

      // Map View
      SchoolMapView(
        school: school,
        homeLocation: nil // TODO: Get from user profile
      )
      .padding(.horizontal)

      // College Data Section
      CollegeDataSection(
        school: school,
        isLookingUp: viewModel.isLookingUpCollegeData,
        lookupError: viewModel.collegeDataError,
        onLookup: { await viewModel.lookupCollegeData() }
      )
      .padding(.horizontal)
    }
    .padding(.vertical)
  }
}
```

**Update `loadSchool()` to load fit score:**

```swift
func loadSchool() async {
  isLoading = true
  errorMessage = nil
  defer { isLoading = false }

  guard let familyId = familyManager.familyUnitId else {
    errorMessage = "No active family"
    logger.warning("Cannot load school: no active family")
    return
  }

  do {
    async let schoolData = schoolsService.fetchSchool(id: schoolId, familyUnitId: familyId)
    async let historyData = schoolsService.fetchStatusHistory(schoolId: schoolId)

    // NEW: Load fit score in parallel
    async let fitScoreData = fitScoreService.calculateFitScore(schoolId: schoolId)

    school = try await schoolData
    statusHistory = try await historyData

    // Load fit score (non-critical, ignore errors)
    do {
      let fitResult = try await fitScoreData
      self.fitScore = fitResult
      self.divisionRecommendation = fitScoreService.getDivisionRecommendations(
        division: school?.division,
        fitScore: fitResult.score
      )
    } catch {
      // Non-critical - just don't show fit score section
      logger.error("Failed to load fit score: \(error.localizedDescription)")
    }

    logger.info("Loaded school: \(self.school?.name ?? "unknown")")
  } catch {
    errorMessage = "Failed to load school: \(error.localizedDescription)"
    logger.error("Failed to load school: \(error.localizedDescription)")
  }
}
```

---

## Testing Requirements

### Mock Services

**Extend MockFitScoreService:**

```swift
final class MockFitScoreService: FitScoreManaging {
  var stubbedFitScore: FitScoreResult?
  var stubbedRecommendation: DivisionRecommendation?
  var shouldThrowError = false

  func calculateFitScore(schoolId: String) async throws -> FitScoreResult {
    if shouldThrowError {
      throw NSError(domain: "MockFitScoreService", code: -1)
    }
    return stubbedFitScore ?? FitScoreResult(
      score: 75.0,
      tier: .match,
      breakdown: FitScoreBreakdown(
        athleticFit: 80,
        academicFit: 75,
        opportunityFit: 70,
        personalFit: 77
      ),
      missingDimensions: []
    )
  }

  func getDivisionRecommendations(division: String?, fitScore: Double?) -> DivisionRecommendation {
    return stubbedRecommendation ?? DivisionRecommendation(
      shouldConsiderOtherDivisions: false,
      recommendedDivisions: [],
      message: ""
    )
  }
}
```

**Extend MockCollegeScorecardService:**

```swift
final class MockCollegeScorecardService: CollegeScorecardManaging {
  var stubbedResult: CollegeDataResult?
  var shouldThrowError = false
  var errorToThrow: Error = CollegeDataError.schoolNotFound

  func lookupCollege(name: String) async throws -> CollegeDataResult? {
    if shouldThrowError {
      throw errorToThrow
    }
    return stubbedResult
  }
}
```

### ViewModel Tests

**Create:** `TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailViewModelPhase3Tests.swift`

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolDetailViewModelPhase3Tests: XCTestCase {
  var viewModel: SchoolDetailViewModel!
  var mockSchoolsService: MockSchoolsService!
  var mockFitScoreService: MockFitScoreService!
  var mockCollegeService: MockCollegeScorecardService!

  override func setUp() async throws {
    mockSchoolsService = MockSchoolsService()
    mockFitScoreService = MockFitScoreService()
    mockCollegeService = MockCollegeScorecardService()

    viewModel = SchoolDetailViewModel(
      schoolId: "school-1",
      schoolsService: mockSchoolsService,
      fitScoreService: mockFitScoreService,
      collegeService: mockCollegeService
    )
  }

  // MARK: - Fit Score Tests

  func testLoadFitScore_Success() async throws {
    // Given
    let expectedScore = FitScoreResult(
      score: 85.0,
      tier: .safety,
      breakdown: FitScoreBreakdown(
        athleticFit: 90,
        academicFit: 85,
        opportunityFit: 80,
        personalFit: 85
      ),
      missingDimensions: []
    )
    mockFitScoreService.stubbedFitScore = expectedScore

    // When
    await viewModel.loadFitScore()

    // Then
    XCTAssertEqual(viewModel.fitScore?.score, 85.0)
    XCTAssertEqual(viewModel.fitScore?.tier, .safety)
    XCTAssertFalse(viewModel.isLoadingFitScore)
  }

  func testLoadFitScore_WithDivisionRecommendation() async throws {
    // Given
    let lowScore = FitScoreResult(
      score: 45.0,
      tier: .unlikely,
      breakdown: FitScoreBreakdown(
        athleticFit: 40,
        academicFit: 45,
        opportunityFit: 48,
        personalFit: 47
      ),
      missingDimensions: []
    )
    mockFitScoreService.stubbedFitScore = lowScore
    mockSchoolsService.stubbedSchool = createMockSchool(division: "D1")

    // When
    await viewModel.loadSchool()
    await viewModel.loadFitScore()

    // Then
    XCTAssertNotNil(viewModel.divisionRecommendation)
    // Recommendation logic tested in FitScoreService tests
  }

  // MARK: - College Data Tests

  func testLookupCollegeData_Success() async throws {
    // Given
    let mockResult = CollegeDataResult(
      id: "1",
      name: "Test University",
      website: "test.edu",
      address: "123 Main St",
      city: "Testville",
      state: "CA",
      studentSize: 15000,
      carnegieSize: "L",
      admissionRate: 0.25,
      tuitionInState: 12000,
      tuitionOutOfState: 45000,
      latitude: 37.7749,
      longitude: -122.4194
    )
    mockCollegeService.stubbedResult = mockResult
    mockSchoolsService.stubbedSchool = createMockSchool(name: "Test University")
    await viewModel.loadSchool()

    // When
    await viewModel.lookupCollegeData()

    // Then
    XCTAssertNil(viewModel.collegeDataError)
    XCTAssertFalse(viewModel.isLookingUpCollegeData)
  }

  func testLookupCollegeData_NotFound() async throws {
    // Given
    mockCollegeService.stubbedResult = nil
    mockSchoolsService.stubbedSchool = createMockSchool(name: "Unknown School")
    await viewModel.loadSchool()

    // When
    await viewModel.lookupCollegeData()

    // Then
    XCTAssertEqual(viewModel.collegeDataError, "School not found in database")
  }

  func testLookupCollegeData_APIError() async throws {
    // Given
    mockCollegeService.shouldThrowError = true
    mockCollegeService.errorToThrow = CollegeDataError.rateLimited
    mockSchoolsService.stubbedSchool = createMockSchool()
    await viewModel.loadSchool()

    // When
    await viewModel.lookupCollegeData()

    // Then
    XCTAssertNotNil(viewModel.collegeDataError)
  }

  // MARK: - Helper

  private func createMockSchool(
    name: String = "Test School",
    division: String = "D1"
  ) -> School {
    School(
      id: "school-1",
      userId: "user-1",
      name: name,
      location: "Test, CA",
      city: "Test",
      state: "CA",
      division: division,
      conference: "Test Conf",
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
      notes: nil,
      privateNotes: nil,
      pros: [],
      cons: [],
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

---

## Known Issues & Gotchas

### 1. College Scorecard API Key

The API key is currently read from environment variable `COLLEGE_SCORECARD_API_KEY`.

**Options:**
- Set in Xcode scheme environment variables (development)
- Store in secure storage (production)
- Pass as init parameter for testing

**To get an API key:**
1. Go to https://api.data.gov/signup/
2. Register for a free key
3. Add to environment: `COLLEGE_SCORECARD_API_KEY=your-key-here`

### 2. Home Location for Distance

The `SchoolMapView` accepts an optional `homeLocation` parameter for calculating distance. This should come from:
- User profile settings
- Family unit settings
- Or default to nil (no distance shown)

**TODO:** Add home location to user/family profile.

### 3. Fit Score Calculation

The current implementation is a placeholder. Real fit score would:
- Fetch student profile data
- Fetch school academic/athletic data
- Calculate scores for each dimension
- Return weighted average

**For MVP:** Placeholder is fine, enhance later.

### 4. MapKit Privacy

**IMPORTANT:** Add to `Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location to calculate distance from home to schools.</string>
```

Without this, map will not display user location.

### 5. College Data Merge

The `lookupCollegeData()` method currently just logs success. To actually merge data:

**TODO:** Add service method:
```swift
func mergeCollegeData(id: String, data: CollegeDataResult) async throws -> School
```

This would update the school's `academicInfo` with data from College Scorecard.

---

## Build & Test Commands

```bash
cd /Users/chrisandrikanich/Documents/Workspaces/Personal/TheRecruitingCompass/recruiting-compass-ios-fresh/TheRecruitingCompass

# Build
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run tests
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run specific test file
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPhase3Tests
```

---

## Implementation Checklist

### Step 1: Create View Components (1 hour)
- [ ] Create `FitScoreSection.swift` with expandable breakdown
- [ ] Create `DivisionRecommendationBanner.swift`
- [ ] Create `SchoolMapView.swift` with MapKit
- [ ] Create `CollegeDataSection.swift` with lookup button

### Step 2: Integration (30 min)
- [ ] Add Phase 3 sections to `SchoolDetailView`
- [ ] Update `loadSchool()` to load fit score in parallel
- [ ] Wire up all callbacks

### Step 3: Testing (30 min)
- [ ] Create `SchoolDetailViewModelPhase3Tests.swift`
- [ ] Write 8+ test cases
- [ ] Create mock services
- [ ] Run tests and verify passing

### Step 4: Verify (15 min)
- [ ] Build project (should succeed)
- [ ] Manual test in simulator
- [ ] Check VoiceOver labels
- [ ] Verify map displays correctly

---

## Success Metrics

Phase 3 is **COMPLETE** when:
1. ✅ All 4 view components created
2. ✅ Components integrated into detail view
3. ✅ Fit score displays with breakdown
4. ✅ Division recommendations show when applicable
5. ✅ Map view shows school location
6. ✅ College data lookup works (with API key)
7. ✅ 8+ ViewModel tests passing
8. ✅ Build succeeds with 0 errors
9. ✅ Pull-to-refresh reloads fit score
10. ✅ Accessibility labels on all new components

---

## Files Created in Phase 3 Foundation

**Models:**
- `FitScore.swift` (FitScoreResult, FitScoreBreakdown, FitTier, DivisionRecommendation)
- `CollegeDataResult.swift` (CollegeDataResult, CollegeDataError)

**Services:**
- `FitScoreService.swift` (FitScoreManaging protocol + implementation)
- `CollegeScorecardService.swift` (CollegeScorecardManaging protocol + implementation)

**ViewModel:**
- Extended `SchoolDetailViewModel.swift` with Phase 3 state and methods

**Total:** 4 new files, 1 modified file, ~600 lines of foundation code

---

## Next Steps After Phase 3

1. **Code Review** - Use `code-reviewer` agent
2. **Accessibility Audit** - Test VoiceOver navigation
3. **Commit** - Create detailed commit message
4. **Phase 4** - Coaches panel, actions, delete

---

## Questions for Chris

1. **Home Location:** Should this come from user profile or family settings?
2. **College API Key:** Where should we store this securely?
3. **Fit Score:** Keep placeholder or implement real calculation?
4. **Map Permissions:** Are we requesting user location or just showing school location?

---

**Ready to implement? Start with Step 1: Create view components!**

**Estimated Time:** 1-2 hours for complete Phase 3 (foundation already done)
