import XCTest
@testable import TheRecruitingCompass

final class OfferCreateRequestTests: XCTestCase {

  // MARK: - Init from FormState

  func testInit_MapsSchoolId() {
    var form = NewOfferFormState()
    form.schoolId = "school-123"

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertEqual(request.schoolId, "school-123")
  }

  func testInit_NilSchoolId_DefaultsToEmptyString() {
    let form = NewOfferFormState()

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertEqual(request.schoolId, "")
  }

  func testInit_MapsUserId() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"

    let request = OfferCreateRequest(userId: "user-42", form: form)

    XCTAssertEqual(request.userId, "user-42")
  }

  func testInit_MapsOfferType() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.offerType = .fullRide

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertEqual(request.offerType, .fullRide)
  }

  func testInit_MapsStatus() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.status = .accepted

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertEqual(request.status, .accepted)
  }

  func testInit_ScholarshipAmount_ValidNumber() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipAmount = "25000"

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertEqual(request.scholarshipAmount, 25000)
  }

  func testInit_ScholarshipAmount_EmptyString_ReturnsNil() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipAmount = ""

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertNil(request.scholarshipAmount)
  }

  func testInit_ScholarshipPercentage_Positive_Included() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipPercentage = 75

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertEqual(request.scholarshipPercentage, 75)
  }

  func testInit_ScholarshipPercentage_Zero_ReturnsNil() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.scholarshipPercentage = 0

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertNil(request.scholarshipPercentage)
  }

  func testInit_DeadlineDate_WhenHasDeadline_Included() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.hasDeadline = true

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertNotNil(request.deadlineDate)
  }

  func testInit_DeadlineDate_WhenNoDeadline_Nil() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.hasDeadline = false

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertNil(request.deadlineDate)
  }

  func testInit_Notes_NonEmpty_Included() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.notes = "Important notes"

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertEqual(request.notes, "Important notes")
  }

  func testInit_Notes_Empty_ReturnsNil() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.notes = ""

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertNil(request.notes)
  }

  func testInit_Conditions_AlwaysNil() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertNil(request.conditions)
  }

  func testInit_OfferDate_FormattedAsYYYYMMDD() {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    let components = DateComponents(year: 2025, month: 6, day: 15)
    form.offerDate = Calendar.current.date(from: components)!

    let request = OfferCreateRequest(userId: "user-1", form: form)

    XCTAssertEqual(request.offerDate, "2025-06-15")
  }

  // MARK: - Codable Tests

  func testCodable_SnakeCaseKeys() throws {
    var form = NewOfferFormState()
    form.schoolId = "school-1"
    form.offerType = .fullRide
    form.scholarshipAmount = "50000"
    form.scholarshipPercentage = 100

    let request = OfferCreateRequest(userId: "user-1", form: form)
    let data = try JSONEncoder().encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    XCTAssertNotNil(json["user_id"])
    XCTAssertNotNil(json["school_id"])
    XCTAssertNotNil(json["offer_type"])
    XCTAssertNotNil(json["scholarship_amount"])
    XCTAssertNotNil(json["scholarship_percentage"])
    XCTAssertNotNil(json["offer_date"])
  }
}
