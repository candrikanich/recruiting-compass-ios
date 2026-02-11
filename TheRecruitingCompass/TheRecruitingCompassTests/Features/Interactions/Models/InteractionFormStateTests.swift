import XCTest
@testable import TheRecruitingCompass

final class InteractionFormStateTests: XCTestCase {

  // MARK: - Initial State Tests

  func testInitialState_DefaultValues() {
    // Given
    let formState = InteractionFormState()

    // Then
    XCTAssertTrue(formState.schoolId.isEmpty)
    XCTAssertNil(formState.coachId)
    XCTAssertNil(formState.type)
    XCTAssertEqual(formState.direction, .outbound)
    XCTAssertTrue(formState.subject.isEmpty)
    XCTAssertTrue(formState.content.isEmpty)
    XCTAssertNil(formState.sentiment)
    XCTAssertEqual(formState.interestLevel, .notSet)
    XCTAssertTrue(formState.attachedFiles.isEmpty)
  }

  // MARK: - Validation Tests

  func testIsValid_FalseWhenSchoolIdEmpty() {
    // Given
    var formState = InteractionFormState()
    formState.schoolId = ""
    formState.type = .email

    // Then
    XCTAssertFalse(formState.isValid)
  }

  func testIsValid_FalseWhenTypeNil() {
    // Given
    var formState = InteractionFormState()
    formState.schoolId = "school1"
    formState.type = nil

    // Then
    XCTAssertFalse(formState.isValid)
  }

  func testIsValid_TrueWhenRequiredFieldsSet() {
    // Given
    var formState = InteractionFormState()
    formState.schoolId = "school1"
    formState.type = .email

    // Then
    XCTAssertTrue(formState.isValid)
  }

  // MARK: - Interest Calibration Visibility Tests

  func testShowsInterestCalibration_FalseWhenOutbound() {
    // Given
    var formState = InteractionFormState()
    formState.direction = .outbound
    formState.sentiment = .veryPositive

    // Then
    XCTAssertFalse(formState.showsInterestCalibration)
  }

  func testShowsInterestCalibration_FalseWhenSentimentNeutral() {
    // Given
    var formState = InteractionFormState()
    formState.direction = .inbound
    formState.sentiment = .neutral

    // Then
    XCTAssertFalse(formState.showsInterestCalibration)
  }

  func testShowsInterestCalibration_FalseWhenSentimentNegative() {
    // Given
    var formState = InteractionFormState()
    formState.direction = .inbound
    formState.sentiment = .negative

    // Then
    XCTAssertFalse(formState.showsInterestCalibration)
  }

  func testShowsInterestCalibration_TrueWhenInboundAndPositive() {
    // Given
    var formState = InteractionFormState()
    formState.direction = .inbound
    formState.sentiment = .positive

    // Then
    XCTAssertTrue(formState.showsInterestCalibration)
  }

  func testShowsInterestCalibration_TrueWhenInboundAndVeryPositive() {
    // Given
    var formState = InteractionFormState()
    formState.direction = .inbound
    formState.sentiment = .veryPositive

    // Then
    XCTAssertTrue(formState.showsInterestCalibration)
  }

  func testShowsInterestCalibration_FalseWhenSentimentNil() {
    // Given
    var formState = InteractionFormState()
    formState.direction = .inbound
    formState.sentiment = nil

    // Then
    XCTAssertFalse(formState.showsInterestCalibration)
  }

  // MARK: - Reset Tests

  func testReset_ClearsAllFields() {
    // Given
    var formState = InteractionFormState()
    formState.schoolId = "school1"
    formState.coachId = "coach1"
    formState.type = .email
    formState.direction = .inbound
    formState.subject = "Subject"
    formState.content = "Content"
    formState.sentiment = .positive
    formState.interestLevel = .high
    formState.attachedFiles = [AttachmentFile(fileName: "file.pdf", fileSize: 1024, mimeType: "application/pdf", data: Data())]

    // When
    formState.reset()

    // Then
    XCTAssertTrue(formState.schoolId.isEmpty)
    XCTAssertNil(formState.coachId)
    XCTAssertNil(formState.type)
    XCTAssertEqual(formState.direction, .outbound)
    XCTAssertTrue(formState.subject.isEmpty)
    XCTAssertTrue(formState.content.isEmpty)
    XCTAssertNil(formState.sentiment)
    XCTAssertEqual(formState.interestLevel, .notSet)
    XCTAssertTrue(formState.attachedFiles.isEmpty)
  }

  func testReset_ResetsOccurredAtToNow() {
    // Given
    var formState = InteractionFormState()
    let pastDate = Date(timeIntervalSinceNow: -86400)
    formState.occurredAt = pastDate

    // When
    formState.reset()

    // Then (occurredAt should be close to now)
    let now = Date()
    XCTAssertEqual(formState.occurredAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 5.0)
  }

  // MARK: - Edge Cases

  func testMutability_AllFieldsCanBeModified() {
    // Given
    var formState = InteractionFormState()

    // When
    formState.schoolId = "school1"
    formState.coachId = "coach1"
    formState.type = .phoneCall
    formState.direction = .inbound
    formState.subject = "Test"
    formState.content = "Content"
    formState.sentiment = .veryPositive
    formState.interestLevel = .medium

    // Then
    XCTAssertEqual(formState.schoolId, "school1")
    XCTAssertEqual(formState.coachId, "coach1")
    XCTAssertEqual(formState.type, .phoneCall)
    XCTAssertEqual(formState.direction, .inbound)
    XCTAssertEqual(formState.subject, "Test")
    XCTAssertEqual(formState.content, "Content")
    XCTAssertEqual(formState.sentiment, .veryPositive)
    XCTAssertEqual(formState.interestLevel, .medium)
  }

  func testIsValid_MultipleScenarios() {
    var formState = InteractionFormState()

    // Scenario 1: Empty form
    XCTAssertFalse(formState.isValid)

    // Scenario 2: Only school
    formState.schoolId = "school1"
    XCTAssertFalse(formState.isValid)

    // Scenario 3: Only type
    formState.schoolId = ""
    formState.type = .email
    XCTAssertFalse(formState.isValid)

    // Scenario 4: Both required fields
    formState.schoolId = "school1"
    formState.type = .email
    XCTAssertTrue(formState.isValid)

    // Scenario 5: With optional fields
    formState.coachId = "coach1"
    formState.subject = "Subject"
    formState.content = "Content"
    XCTAssertTrue(formState.isValid)
  }
}
