import XCTest
@testable import TheRecruitingCompass

final class InterestCalibrationTests: XCTestCase {

  // MARK: - Questions Tests

  func testQuestions_HasSixQuestions() {
    XCTAssertEqual(InterestCalibration.questions.count, 6)
  }

  func testQuestions_AllNonEmpty() {
    for question in InterestCalibration.questions {
      XCTAssertFalse(question.isEmpty)
    }
  }

  // MARK: - Initial State Tests

  func testInitialState_AllAnswersFalse() {
    // Given
    let calibration = InterestCalibration()

    // Then
    XCTAssertEqual(calibration.answers.count, 6)
    XCTAssertTrue(calibration.answers.allSatisfy { $0 == false })
  }

  func testInitialState_YesCountIsZero() {
    // Given
    let calibration = InterestCalibration()

    // Then
    XCTAssertEqual(calibration.yesCount, 0)
  }

  func testInitialState_InterestLevelNotSet() {
    // Given
    let calibration = InterestCalibration()

    // Then
    XCTAssertEqual(calibration.interestLevel, .notSet)
  }

  // MARK: - Yes Count Tests

  func testYesCount_CountsCorrectly() {
    // Given
    var calibration = InterestCalibration()

    // When (2 yes answers)
    calibration.answers[0] = true
    calibration.answers[2] = true

    // Then
    XCTAssertEqual(calibration.yesCount, 2)
  }

  func testYesCount_AllYes() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers = Array(repeating: true, count: 6)

    // Then
    XCTAssertEqual(calibration.yesCount, 6)
  }

  func testYesCount_AllNo() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers = Array(repeating: false, count: 6)

    // Then
    XCTAssertEqual(calibration.yesCount, 0)
  }

  // MARK: - Interest Level Tests

  func testInterestLevel_NotSet_WhenZeroYes() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers = [false, false, false, false, false, false]

    // Then
    XCTAssertEqual(calibration.interestLevel, .notSet)
  }

  func testInterestLevel_Low_WhenOneYes() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers[0] = true

    // Then
    XCTAssertEqual(calibration.interestLevel, .low)
  }

  func testInterestLevel_Medium_WhenTwoYes() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers[0] = true
    calibration.answers[1] = true

    // Then
    XCTAssertEqual(calibration.interestLevel, .medium)
  }

  func testInterestLevel_Medium_WhenThreeYes() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers[0] = true
    calibration.answers[1] = true
    calibration.answers[2] = true

    // Then
    XCTAssertEqual(calibration.interestLevel, .medium)
  }

  func testInterestLevel_High_WhenFourYes() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers[0] = true
    calibration.answers[1] = true
    calibration.answers[2] = true
    calibration.answers[3] = true

    // Then
    XCTAssertEqual(calibration.interestLevel, .high)
  }

  func testInterestLevel_High_WhenFiveYes() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers = [true, true, true, true, true, false]

    // Then
    XCTAssertEqual(calibration.interestLevel, .high)
  }

  func testInterestLevel_High_WhenAllYes() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers = Array(repeating: true, count: 6)

    // Then
    XCTAssertEqual(calibration.interestLevel, .high)
  }

  // MARK: - Result Description Tests

  func testResultDescription_NotSet() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers = Array(repeating: false, count: 6)

    // Then
    XCTAssertEqual(calibration.resultDescription, "Answer questions to see coach interest level")
  }

  func testResultDescription_Low() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers[0] = true

    // Then
    XCTAssertTrue(calibration.resultDescription.contains("Limited signals"))
  }

  func testResultDescription_Medium() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers[0] = true
    calibration.answers[1] = true

    // Then
    XCTAssertTrue(calibration.resultDescription.contains("seems interested"))
  }

  func testResultDescription_High() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers = Array(repeating: true, count: 6)

    // Then
    XCTAssertTrue(calibration.resultDescription.contains("strong signals"))
  }

  // MARK: - Reset Tests

  func testReset_ClearsAllAnswers() {
    // Given
    var calibration = InterestCalibration()
    calibration.answers = [true, true, true, true, true, true]

    // When
    calibration.reset()

    // Then
    XCTAssertTrue(calibration.answers.allSatisfy { $0 == false })
    XCTAssertEqual(calibration.yesCount, 0)
    XCTAssertEqual(calibration.interestLevel, .notSet)
  }

  // MARK: - Edge Cases

  func testThresholds_ExactBoundaries() {
    var calibration = InterestCalibration()

    // 0 yes = notSet
    calibration.answers = [false, false, false, false, false, false]
    XCTAssertEqual(calibration.interestLevel, .notSet)

    // 1 yes = low
    calibration.answers = [true, false, false, false, false, false]
    XCTAssertEqual(calibration.interestLevel, .low)

    // 2 yes = medium
    calibration.answers = [true, true, false, false, false, false]
    XCTAssertEqual(calibration.interestLevel, .medium)

    // 3 yes = medium
    calibration.answers = [true, true, true, false, false, false]
    XCTAssertEqual(calibration.interestLevel, .medium)

    // 4 yes = high
    calibration.answers = [true, true, true, true, false, false]
    XCTAssertEqual(calibration.interestLevel, .high)
  }

  func testAnswers_MutabilityPreserved() {
    // Given
    var calibration = InterestCalibration()

    // When
    calibration.answers[3] = true
    calibration.answers[3] = false
    calibration.answers[3] = true

    // Then
    XCTAssertTrue(calibration.answers[3])
    XCTAssertEqual(calibration.yesCount, 1)
  }
}
