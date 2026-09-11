import XCTest
@testable import TheRecruitingCompass

final class OnboardingAssessmentTests: XCTestCase {

  private var referenceDate: Date {
    // 2026-09-11 — matches the web parity fix's repro date.
    var comps = DateComponents()
    comps.year = 2026; comps.month = 9; comps.day = 11
    return Calendar.current.date(from: comps)!
  }

  func testStartingPhase_noAssessmentSignal_noGraduationYear_returnsFreshman() {
    let assessment = OnboardingAssessment()
    XCTAssertEqual(OnboardingAssessment.startingPhase(for: assessment, graduationYear: nil), "freshman")
  }

  // Regression for the bug this fix addresses: a rising junior (grad 2028, viewed 2026-09-11)
  // with no assessment signal must NOT be stamped "freshman".
  func testStartingPhase_usesGradeDerivedPhase_whenAssessmentHasNoSignal() {
    let assessment = OnboardingAssessment()
    let grade = GradeLevelHelper.calculateCurrentGrade(graduationYear: 2028, referenceDate: referenceDate)
    XCTAssertEqual(grade, 11, "sanity check: grad 2028 on 2026-09-11 is grade 11 (junior)")

    // startingPhase(for:graduationYear:) always uses Date.now internally for the grade calc,
    // so assert against the grade-derived phase directly rather than freezing the clock.
    let expectedPhase = GradeLevelHelper.phase(forGrade: GradeLevelHelper.calculateCurrentGrade(graduationYear: 2028))
    XCTAssertEqual(OnboardingAssessment.startingPhase(for: assessment, graduationYear: 2028), expectedPhase)
    XCTAssertNotEqual(expectedPhase, "freshman", "grad year 2028 today should not resolve to freshman")
  }

  func testStartingPhase_assessmentSignal_notRegressedByLowerGrade() {
    var assessment = OnboardingAssessment()
    assessment.hasRegisteredEligibility = true
    // Grade-derived phase for a far-future grad year is "freshman", but the assessment
    // already signals "junior" — the higher-ranked signal must win.
    let farFutureYear = Calendar.current.component(.year, from: Date()) + 10
    XCTAssertEqual(OnboardingAssessment.startingPhase(for: assessment, graduationYear: farFutureYear), "junior")
  }

  func testStartingPhase_sophomoreSignal_video_andTargetSchools() {
    var assessment = OnboardingAssessment()
    assessment.hasHighlightVideo = true
    assessment.hasTargetSchools = true
    XCTAssertEqual(OnboardingAssessment.startingPhase(for: assessment, graduationYear: nil), "sophomore")
  }

  func testStartingPhase_testScoresSignal_returnsJunior() {
    var assessment = OnboardingAssessment()
    assessment.hasTakenTestScores = true
    XCTAssertEqual(OnboardingAssessment.startingPhase(for: assessment, graduationYear: nil), "junior")
  }
}
