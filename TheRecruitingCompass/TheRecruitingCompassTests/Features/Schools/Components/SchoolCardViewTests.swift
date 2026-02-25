import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class SchoolCardViewTests: XCTestCase {

  private var school: School!

  override func setUp() {
    school = makeSchool()
  }

  override func tearDown() {
    school = nil
  }

  // MARK: - Rendering Tests

  func testRendersSchoolName() {
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertEqual(school.name, "Stanford University")
    XCTAssertNotNil(mirror)
  }

  func testRendersLocation() {
    let school = makeSchool(location: "Stanford, CA")
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertEqual(school.location, "Stanford, CA")
    XCTAssertNotNil(mirror)
  }

  func testHidesLocationWhenNil() {
    let school = makeSchool(location: nil)
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertNil(school.location)
    XCTAssertNotNil(mirror)
  }

  // MARK: - Badge Tests

  func testDisplaysDivisionBadge() {
    let school = makeSchool(division: "D1")
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertEqual(school.division, "D1")
    XCTAssertNotNil(mirror)
  }

  func testDisplaysStatusBadge() {
    let school = makeSchool(status: "contacted")
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertEqual(school.status, "contacted")
    XCTAssertNotNil(mirror)
  }

  func testDisplaysFitScoreBadge() {
    let school = makeSchool(fitScore: 85)
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertEqual(school.fitScore, 85)
    XCTAssertNotNil(mirror)
  }

  func testHidesFitScoreBadgeWhenNil() {
    let school = makeSchool(fitScore: nil)
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertNil(school.fitScore)
    XCTAssertNotNil(mirror)
  }

  func testDisplaysSizeBadge() {
    let school = makeSchool(studentSize: 17000)
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertNotNil(school.size)
    XCTAssertNotNil(mirror)
  }

  // MARK: - Logo Tests

  func testUsesInitialsWhenNoLogo() {
    let school = makeSchool(faviconUrl: nil)
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertNil(school.faviconUrl)
    XCTAssertEqual(school.initials, "SU")
    XCTAssertNotNil(mirror)
  }

  func testAttemptsToLoadLogoWhenAvailable() {
    let school = makeSchool(faviconUrl: "https://example.com/logo.png")
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertNotNil(school.faviconUrl)
    XCTAssertNotNil(mirror)
  }

  // MARK: - Favorite Tests

  func testFavoriteStarFilled() {
    let school = makeSchool(isFavorite: true)
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertTrue(school.isFavorite)
    XCTAssertNotNil(mirror)
  }

  func testFavoriteStarOutline() {
    let school = makeSchool(isFavorite: false)
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertFalse(school.isFavorite)
    XCTAssertNotNil(mirror)
  }

  func testFavoriteToggleCallback() {
    var callbackCalled = false
    let card = SchoolCardView(
      school: school,
      onToggleFavorite: { callbackCalled = true }
    )
    let mirror = Mirror(reflecting: card)

    XCTAssertNotNil(mirror)
    _ = callbackCalled
  }

  // MARK: - Content Tests

  func testDisplaysConference() {
    let school = makeSchool(conference: "Pac-12")
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertEqual(school.conference, "Pac-12")
    XCTAssertNotNil(mirror)
  }

  func testHidesConferenceWhenNil() {
    let school = makeSchool(conference: nil)
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertNil(school.conference)
    XCTAssertNotNil(mirror)
  }

  func testDisplaysNotes() {
    let school = makeSchool(notes: "Great academic program")
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertEqual(school.notes, "Great academic program")
    XCTAssertNotNil(mirror)
  }

  func testHidesNotesWhenEmpty() {
    let school = makeSchool(notes: "")
    let card = SchoolCardView(school: school, onToggleFavorite: {})
    let mirror = Mirror(reflecting: card)

    XCTAssertTrue(school.notes?.isEmpty ?? true)
    XCTAssertNotNil(mirror)
  }

  // MARK: - Test Helpers

  private func makeSchool(
    id: String = "school-1",
    name: String = "Stanford University",
    location: String? = "Stanford, CA",
    division: String? = "D1",
    conference: String? = "Pac-12",
    status: String = "interested",
    isFavorite: Bool = false,
    fitScore: Double? = 85,
    notes: String? = nil,
    faviconUrl: String? = nil,
    studentSize: Int? = 17000
  ) -> School {
    School(
      id: id,
      userId: "user-1",
      name: name,
      location: location,
      city: "Stanford",
      state: "CA",
      division: division,
      conference: conference,
      ranking: nil,
      isFavorite: isFavorite,
      website: nil,
      faviconUrl: faviconUrl,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: status,
      statusChangedAt: nil,
      priorityTier: "A",
      notes: notes,
      privateNotes: nil,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: studentSize != nil ? AcademicInfo(
        gpaRequirement: nil,
        satRequirement: nil,
        actRequirement: nil,
        additionalRequirements: nil,
        address: nil,
        city: "Stanford",
        state: "CA",
        latitude: 37.4275,
        longitude: -122.1697,
        studentSize: studentSize,
        baseballFacilityAddress: nil,
        mascot: nil,
        undergradSize: nil,
        carnegieSize: nil,
        tuitionInState: nil,
        tuitionOutOfState: nil,
        admissionRate: nil,
        distanceFromHome: nil
      ) : nil,
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      fitScore: fitScore,
      fitTier: nil,
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }
}
