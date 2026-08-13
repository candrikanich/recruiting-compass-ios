import XCTest
@testable import TheRecruitingCompass

final class AcademicInfoRangeDecodingTests: XCTestCase {
  func test_decodesSatActPercentileRanges() throws {
    let json = """
    {"sat_25th": 1120, "sat_75th": 1330, "act_25th": 24, "act_75th": 30, "admission_rate": 0.42}
    """.data(using: .utf8)!
    let info = try JSONDecoder().decode(AcademicInfo.self, from: json)
    XCTAssertEqual(info.sat25th, 1120)
    XCTAssertEqual(info.sat75th, 1330)
    XCTAssertEqual(info.act25th, 24)
    XCTAssertEqual(info.act75th, 30)
    XCTAssertEqual(info.admissionRate, 0.42)
  }

  func test_missingRangesDecodeAsNil() throws {
    let json = "{\"admission_rate\": 0.5}".data(using: .utf8)!
    let info = try JSONDecoder().decode(AcademicInfo.self, from: json)
    XCTAssertNil(info.sat25th)
    XCTAssertNil(info.act25th)
  }

  func test_schoolWithAcademicInfoReplacesOnlyAcademicInfo() {
    let base = School(id: "s1", userId: "u1", name: "Test U", location: nil, city: nil,
      state: "CA", division: nil, conference: nil, ranking: nil, isFavorite: true,
      website: nil, faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, phone: nil,
      ncaaId: nil, status: "interested", statusChangedAt: nil, notes: nil, pros: [], cons: [],
      offerDetails: nil, academicInfo: nil, amenities: nil, coachingPhilosophy: nil,
      coachingStyle: nil, recruitingApproach: nil, communicationStyle: nil, successMetrics: nil,
      familyUnitId: "f1", createdBy: nil, updatedBy: nil, createdAt: "", updatedAt: "")
    let updated = base.with(academicInfo: AcademicInfo(sat25th: 1100))
    XCTAssertEqual(updated.academicInfo?.sat25th, 1100)
    XCTAssertTrue(updated.isFavorite)
    XCTAssertEqual(updated.state, "CA")
  }
}
