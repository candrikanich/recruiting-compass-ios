import XCTest
import CoreLocation
@testable import TheRecruitingCompass

@MainActor
final class SchoolMapViewTests: XCTestCase {
  nonisolated deinit {}

  private func school(lat: Double?, lon: Double?) -> School {
    School(
      id: "1", userId: "u1", name: "Wake Forest", location: "Winston-Salem, NC",
      city: "Winston-Salem", state: "NC", division: "D1", conference: "ACC",
      ranking: nil, isFavorite: false, website: nil, faviconUrl: nil,
      twitterHandle: nil, instagramHandle: nil, ncaaId: nil, status: "interested",
      statusChangedAt: nil, notes: nil, pros: [], cons: [], offerDetails: nil,
      academicInfo: AcademicInfo(
        gpaRequirement: nil, satRequirement: nil, actRequirement: nil,
        additionalRequirements: nil, address: nil, city: nil, state: nil,
        latitude: lat, longitude: lon, studentSize: nil,
        baseballFacilityAddress: nil, mascot: nil, undergradSize: nil,
        carnegieSize: nil, tuitionInState: nil, tuitionOutOfState: nil,
        admissionRate: nil, distanceFromHome: nil
      ),
      amenities: nil, coachingPhilosophy: nil, coachingStyle: nil,
      recruitingApproach: nil, communicationStyle: nil, successMetrics: nil,
      fitScore: nil, fitTier: nil, familyUnitId: "f1", createdBy: nil,
      updatedBy: nil, createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  func testState_distance_whenSchoolAndHomeCoordsPresent() {
    let view = SchoolMapView(
      school: school(lat: 36.1330, lon: -80.2770),
      homeLocation: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    )
    guard case .distance(let label) = view.mapState else {
      return XCTFail("expected .distance")
    }
    XCTAssertTrue(label.contains("miles"))
  }

  func testState_setHomeCTA_whenSchoolCoordsButNoHome() {
    let view = SchoolMapView(school: school(lat: 36.1330, lon: -80.2770), homeLocation: nil)
    guard case .setHomeCTA = view.mapState else {
      return XCTFail("expected .setHomeCTA")
    }
  }

  func testState_noSchoolCoords_whenSchoolMissingCoords() {
    let view = SchoolMapView(
      school: school(lat: nil, lon: nil),
      homeLocation: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    )
    guard case .noSchoolCoords = view.mapState else {
      return XCTFail("expected .noSchoolCoords")
    }
  }
}
