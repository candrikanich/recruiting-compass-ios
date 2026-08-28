import CoreLocation
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class FilterAndSortSchoolsUseCaseTests: XCTestCase {
  nonisolated deinit {}

  private let sut = FilterAndSortSchoolsUseCase()

  func testSearch_matchesNameCityStateConferenceNotes() {
    let schools = [
      makeSchool(id: "1", name: "Stanford", city: "Palo Alto", state: "CA", conference: "ACC"),
      makeSchool(id: "2", name: "Duke", city: "Durham", state: "NC", notes: "Power conference")
    ]

    let byName = sut.execute(schools: schools, filters: SchoolFilters(searchText: "stan"), homeLocation: nil, overallFit: { _ in nil }, distance: { _, _ in nil })
    XCTAssertEqual(byName.map(\.id), ["1"])

    let byState = sut.execute(schools: schools, filters: SchoolFilters(searchText: "NC"), homeLocation: nil, overallFit: { _ in nil }, distance: { _, _ in nil })
    XCTAssertEqual(byState.map(\.id), ["2"])

    let byNotes = sut.execute(schools: schools, filters: SchoolFilters(searchText: "power"), homeLocation: nil, overallFit: { _ in nil }, distance: { _, _ in nil })
    XCTAssertEqual(byNotes.map(\.id), ["2"])
  }

  func testFilters_divisionStatusStateFavorites() {
    let schools = [
      makeSchool(id: "1", state: "CA", division: "D1", isFavorite: true, status: "interested"),
      makeSchool(id: "2", state: "TX", division: "D2", isFavorite: false, status: "researching"),
      makeSchool(id: "3", state: "CA", division: "D1", isFavorite: false, status: "interested")
    ]

    let d1 = sut.execute(schools: schools, filters: SchoolFilters(division: .d1), homeLocation: nil, overallFit: { _ in nil }, distance: { _, _ in nil })
    XCTAssertEqual(d1.map(\.id), ["1", "3"])

    let favorites = sut.execute(schools: schools, filters: SchoolFilters(isFavoritesOnly: true), homeLocation: nil, overallFit: { _ in nil }, distance: { _, _ in nil })
    XCTAssertEqual(favorites.map(\.id), ["1"])
  }

  func testSort_nameAZ() {
    let schools = [
      makeSchool(id: "2", name: "Yale"),
      makeSchool(id: "1", name: "Auburn")
    ]
    let result = sut.execute(schools: schools, filters: SchoolFilters(sortBy: .nameAZ), homeLocation: nil, overallFit: { _ in nil }, distance: { _, _ in nil })
    XCTAssertEqual(result.map(\.name), ["Auburn", "Yale"])
  }

  func testSort_personalFit_strongBeforeStretch() {
    let schools = [makeSchool(id: "stretch"), makeSchool(id: "strong")]
    let result = sut.execute(
      schools: schools,
      filters: SchoolFilters(sortBy: .personalFit),
      homeLocation: nil,
      overallFit: { school in
        school.id == "strong"
          ? OverallPersonalFit(strength: .strong)
          : OverallPersonalFit(strength: .stretch)
      },
      distance: { _, _ in nil }
    )
    XCTAssertEqual(result.map(\.id), ["strong", "stretch"])
  }

  func testDistanceFilter_dropsSchoolsBeyondMax() {
    let home = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    let schools = [makeSchool(id: "near"), makeSchool(id: "far")]
    var filters = SchoolFilters()
    filters.maxDistance = 50
    let result = sut.execute(
      schools: schools,
      filters: filters,
      homeLocation: home,
      overallFit: { _ in nil },
      distance: { school, _ in school.id == "near" ? 10 : 200 }
    )
    XCTAssertEqual(result.map(\.id), ["near"])
  }

  private func makeSchool(
    id: String,
    name: String = "School",
    city: String? = nil,
    state: String? = nil,
    division: String? = "D1",
    conference: String? = nil,
    isFavorite: Bool = false,
    status: String = "interested",
    notes: String? = nil
  ) -> School {
    School(
      id: id,
      userId: "user-1",
      name: name,
      location: nil,
      city: city,
      state: state,
      division: division,
      conference: conference,
      ranking: nil,
      isFavorite: isFavorite,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: status,
      statusChangedAt: "2026-02-01T10:00:00Z",
      notes: notes,
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
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }
}
