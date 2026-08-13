import XCTest
@testable import TheRecruitingCompass

final class AcademicFitCalculatorTests: XCTestCase {
  private func school(sat25: Int? = nil, sat75: Int? = nil, act25: Int? = nil,
                      act75: Int? = nil, rate: Double? = nil) -> School {
    School(id: "s1", userId: "u1", name: "U", location: nil, city: nil, state: nil,
      division: nil, conference: nil, ranking: nil, isFavorite: false, website: nil,
      faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, phone: nil, ncaaId: nil,
      status: "interested", statusChangedAt: nil, notes: nil, pros: [], cons: [],
      offerDetails: nil,
      academicInfo: AcademicInfo(admissionRate: rate, sat25th: sat25, sat75th: sat75,
                                 act25th: act25, act75th: act75),
      amenities: nil, coachingPhilosophy: nil, coachingStyle: nil, recruitingApproach: nil,
      communicationStyle: nil, successMetrics: nil, familyUnitId: "f1", createdBy: nil,
      updatedBy: nil, createdAt: "", updatedAt: "")
  }

  private func athlete(sat: Int? = nil, act: Int? = nil) -> PlayerDetails {
    var p = PlayerDetails()
    p.satScore = sat
    p.actScore = act
    return p
  }

  func test_satAboveRange() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(sat: 1400),
                                            school: school(sat25: 1120, sat75: 1330))
    XCTAssertEqual(a.sat.strength, .above)
    XCTAssertTrue(a.hasSchoolData)
  }

  func test_satInRange() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(sat: 1200),
                                            school: school(sat25: 1120, sat75: 1330))
    XCTAssertEqual(a.sat.strength, .inRange)
  }

  func test_satBelowRange() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(sat: 1000),
                                            school: school(sat25: 1120, sat75: 1330))
    XCTAssertEqual(a.sat.strength, .below)
  }

  func test_noAthleteScoreIsUnknownWithProfilePrompt() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(sat: nil),
                                            school: school(sat25: 1120, sat75: 1330))
    XCTAssertEqual(a.sat.strength, .unknown)
    XCTAssertEqual(a.sat.explanation, "Add your SAT score to your profile.")
  }

  func test_noSchoolRangeIsUnknownWithNoDataMessage() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(act: 28), school: school())
    XCTAssertEqual(a.act.strength, .unknown)
    XCTAssertEqual(a.act.explanation, "No ACT data available for this school.")
    XCTAssertFalse(a.hasSchoolData)
  }

  func test_hasSchoolDataTrueWhenOnlyActRangePresent() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(), school: school(act25: 24, act75: 30))
    XCTAssertTrue(a.hasSchoolData)
  }

  func test_admissionRatePassedThrough() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(), school: school(rate: 0.37))
    XCTAssertEqual(a.admissionRate, 0.37)
  }
}
