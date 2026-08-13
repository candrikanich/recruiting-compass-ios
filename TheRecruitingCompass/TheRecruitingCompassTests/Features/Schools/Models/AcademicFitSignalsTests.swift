import XCTest
@testable import TheRecruitingCompass

final class AcademicFitSignalsTests: XCTestCase {
  func test_strengthBadgeColors() {
    XCTAssertEqual(TestScoreStrength.above.badgeColor, .emerald)
    XCTAssertEqual(TestScoreStrength.inRange.badgeColor, .emerald)
    XCTAssertEqual(TestScoreStrength.below.badgeColor, .orange)
    XCTAssertEqual(TestScoreStrength.unknown.badgeColor, .slate)
  }

  func test_strengthLabels() {
    XCTAssertEqual(TestScoreStrength.above.label, "Above range")
    XCTAssertEqual(TestScoreStrength.inRange.label, "In range")
    XCTAssertEqual(TestScoreStrength.below.label, "Below range")
    XCTAssertEqual(TestScoreStrength.unknown.label, "No data")
  }

  func test_analysisAvailableSignalsCountsKnown() {
    let sat = AcademicFitSignal(label: "SAT", value: nil, strength: .above, explanation: "")
    let act = AcademicFitSignal(label: "ACT", value: nil, strength: .unknown, explanation: "")
    let analysis = AcademicFitAnalysis(sat: sat, act: act, hasSchoolData: true, admissionRate: 0.4)
    XCTAssertEqual(analysis.availableSignals, 1)
    XCTAssertEqual(analysis.orderedSignals.map(\.label), ["SAT", "ACT"])
  }
}
