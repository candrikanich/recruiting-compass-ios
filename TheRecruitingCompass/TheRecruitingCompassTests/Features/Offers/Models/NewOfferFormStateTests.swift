import XCTest
@testable import TheRecruitingCompass

final class NewOfferFormStateTests: XCTestCase {

  // MARK: - Default Initialization

  func testDefaultInitialization() {
    let form = NewOfferFormState()

    XCTAssertNil(form.schoolId)
    XCTAssertEqual(form.offerType, .scholarship)
    XCTAssertEqual(form.status, .pending)
    XCTAssertEqual(form.scholarshipPercentage, 0)
    XCTAssertEqual(form.scholarshipAmount, "")
    XCTAssertFalse(form.hasDeadline)
    XCTAssertTrue(form.notes.isEmpty)
  }

  // MARK: - validationErrors Tests

  func testValidationErrors_NoSchool_ReturnsError() {
    let form = NewOfferFormState()
    XCTAssertTrue(form.validationErrors.contains("Please select a school"))
  }

  func testValidationErrors_WithSchool_NoSchoolError() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    XCTAssertFalse(form.validationErrors.contains("Please select a school"))
  }

  func testValidationErrors_NegativePercentage_ReturnsError() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipPercentage = -1
    XCTAssertTrue(form.validationErrors.contains("Scholarship percentage must be 0-100"))
  }

  func testValidationErrors_PercentageOver100_ReturnsError() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipPercentage = 101
    XCTAssertTrue(form.validationErrors.contains("Scholarship percentage must be 0-100"))
  }

  func testValidationErrors_PercentageAt0_NoError() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    XCTAssertTrue(form.validationErrors.isEmpty)
  }

  func testValidationErrors_PercentageAt100_NoError() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipPercentage = 100
    XCTAssertTrue(form.validationErrors.isEmpty)
  }

  func testValidationErrors_InvalidAmountString_ReturnsError() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipAmount = "not-a-number"
    XCTAssertTrue(form.validationErrors.contains("Scholarship amount must be a valid number"))
  }

  func testValidationErrors_ValidAmountString_NoError() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipAmount = "25000"
    XCTAssertTrue(form.validationErrors.isEmpty)
  }

  func testValidationErrors_EmptyAmountString_NoError() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipAmount = ""
    XCTAssertTrue(form.validationErrors.isEmpty)
  }

  func testValidationErrors_MultipleErrors() {
    var form = NewOfferFormState()
    form.scholarshipPercentage = -5
    form.scholarshipAmount = "abc"

    XCTAssertEqual(form.validationErrors.count, 3)
  }

  // MARK: - isValid Tests

  func testIsValid_WhenNoErrors_ReturnsTrue() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    XCTAssertTrue(form.isValid)
  }

  func testIsValid_WhenErrors_ReturnsFalse() {
    let form = NewOfferFormState()
    XCTAssertFalse(form.isValid)
  }

  // MARK: - reset Tests

  func testReset_ClearsAllFields() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.offerType = .fullRide
    form.status = .accepted
    form.scholarshipPercentage = 75
    form.scholarshipAmount = "50000"
    form.hasDeadline = true
    form.notes = "Great offer"

    form.reset()

    XCTAssertNil(form.schoolId)
    XCTAssertEqual(form.offerType, .scholarship)
    XCTAssertEqual(form.status, .pending)
    XCTAssertEqual(form.scholarshipPercentage, 0)
    XCTAssertEqual(form.scholarshipAmount, "")
    XCTAssertFalse(form.hasDeadline)
    XCTAssertTrue(form.notes.isEmpty)
  }

  func testReset_ResultsInInvalidState() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    XCTAssertTrue(form.isValid)

    form.reset()

    XCTAssertFalse(form.isValid)
  }
}
