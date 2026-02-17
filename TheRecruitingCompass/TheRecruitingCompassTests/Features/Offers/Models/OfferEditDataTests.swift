import XCTest
@testable import TheRecruitingCompass

final class OfferEditDataTests: XCTestCase {

  // MARK: - Default Initialization

  func testDefaultInit() {
    let data = OfferEditData()

    XCTAssertEqual(data.offerType, .scholarship)
    XCTAssertEqual(data.status, .pending)
    XCTAssertNil(data.scholarshipAmount)
    XCTAssertNil(data.scholarshipPercentage)
    XCTAssertNil(data.deadlineDate)
    XCTAssertTrue(data.conditions.isEmpty)
    XCTAssertTrue(data.notes.isEmpty)
  }

  // MARK: - Init from Offer

  func testInitFromOffer_MapsOfferType() {
    let offer = makeTestOffer(id: "1", offerType: .fullRide)
    let data = OfferEditData(from: offer)
    XCTAssertEqual(data.offerType, .fullRide)
  }

  func testInitFromOffer_MapsStatus() {
    let offer = makeTestOffer(id: "1", status: .accepted)
    let data = OfferEditData(from: offer)
    XCTAssertEqual(data.status, .accepted)
  }

  func testInitFromOffer_MapsScholarshipAmount() {
    let offer = makeTestOffer(id: "1", scholarshipAmount: 25000)
    let data = OfferEditData(from: offer)
    XCTAssertEqual(data.scholarshipAmount, 25000)
  }

  func testInitFromOffer_NilScholarshipAmount() {
    let offer = makeTestOffer(id: "1", scholarshipAmount: nil)
    let data = OfferEditData(from: offer)
    XCTAssertNil(data.scholarshipAmount)
  }

  func testInitFromOffer_MapsScholarshipPercentage() {
    let offer = makeTestOffer(id: "1", scholarshipPercentage: 75)
    let data = OfferEditData(from: offer)
    XCTAssertEqual(data.scholarshipPercentage, 75)
  }

  func testInitFromOffer_NilScholarshipPercentage() {
    let offer = makeTestOffer(id: "1", scholarshipPercentage: nil)
    let data = OfferEditData(from: offer)
    XCTAssertNil(data.scholarshipPercentage)
  }

  func testInitFromOffer_MapsOfferDate() {
    let offer = makeTestOffer(id: "1", offerDate: "2025-06-15")
    let data = OfferEditData(from: offer)
    let expected = Offer.parseDate("2025-06-15")
    XCTAssertEqual(data.offerDate, expected)
  }

  func testInitFromOffer_MapsDeadlineDate() {
    let offer = makeOffer(deadlineDate: "2025-12-31")
    let data = OfferEditData(from: offer)
    XCTAssertNotNil(data.deadlineDate)
  }

  func testInitFromOffer_NilDeadlineDate() {
    let offer = makeOffer(deadlineDate: nil)
    let data = OfferEditData(from: offer)
    XCTAssertNil(data.deadlineDate)
  }

  func testInitFromOffer_MapsConditions() {
    let offer = makeOffer(conditions: "Must maintain 3.0 GPA")
    let data = OfferEditData(from: offer)
    XCTAssertEqual(data.conditions, "Must maintain 3.0 GPA")
  }

  func testInitFromOffer_NilConditions_DefaultsToEmpty() {
    let offer = makeOffer(conditions: nil)
    let data = OfferEditData(from: offer)
    XCTAssertEqual(data.conditions, "")
  }

  func testInitFromOffer_MapsNotes() {
    let offer = makeOffer(notes: "Good school")
    let data = OfferEditData(from: offer)
    XCTAssertEqual(data.notes, "Good school")
  }

  func testInitFromOffer_NilNotes_DefaultsToEmpty() {
    let offer = makeOffer(notes: nil)
    let data = OfferEditData(from: offer)
    XCTAssertEqual(data.notes, "")
  }

  // MARK: - OfferUpdateRequest Tests

  func testUpdateRequest_MapsOfferType() {
    var editData = OfferEditData()
    editData.offerType = .fullRide
    let request = OfferUpdateRequest(from: editData)
    XCTAssertEqual(request.offerType, .fullRide)
  }

  func testUpdateRequest_MapsStatus() {
    var editData = OfferEditData()
    editData.status = .declined
    let request = OfferUpdateRequest(from: editData)
    XCTAssertEqual(request.status, .declined)
  }

  func testUpdateRequest_MapsScholarshipAmount() {
    var editData = OfferEditData()
    editData.scholarshipAmount = 40000
    let request = OfferUpdateRequest(from: editData)
    XCTAssertEqual(request.scholarshipAmount, 40000)
  }

  func testUpdateRequest_NilScholarshipAmount() {
    let editData = OfferEditData()
    let request = OfferUpdateRequest(from: editData)
    XCTAssertNil(request.scholarshipAmount)
  }

  func testUpdateRequest_OfferDate_FormattedAsYYYYMMDD() {
    var editData = OfferEditData()
    let components = DateComponents(year: 2025, month: 8, day: 20)
    editData.offerDate = Calendar.current.date(from: components)!
    let request = OfferUpdateRequest(from: editData)
    XCTAssertEqual(request.offerDate, "2025-08-20")
  }

  func testUpdateRequest_DeadlineDate_WhenSet() {
    var editData = OfferEditData()
    let components = DateComponents(year: 2025, month: 12, day: 1)
    editData.deadlineDate = Calendar.current.date(from: components)!
    let request = OfferUpdateRequest(from: editData)
    XCTAssertEqual(request.deadlineDate, "2025-12-01")
  }

  func testUpdateRequest_DeadlineDate_WhenNil() {
    let editData = OfferEditData()
    let request = OfferUpdateRequest(from: editData)
    XCTAssertNil(request.deadlineDate)
  }

  func testUpdateRequest_EmptyConditions_MappedToNil() {
    var editData = OfferEditData()
    editData.conditions = ""
    let request = OfferUpdateRequest(from: editData)
    XCTAssertNil(request.conditions)
  }

  func testUpdateRequest_NonEmptyConditions_Preserved() {
    var editData = OfferEditData()
    editData.conditions = "Must maintain GPA"
    let request = OfferUpdateRequest(from: editData)
    XCTAssertEqual(request.conditions, "Must maintain GPA")
  }

  func testUpdateRequest_EmptyNotes_MappedToNil() {
    var editData = OfferEditData()
    editData.notes = ""
    let request = OfferUpdateRequest(from: editData)
    XCTAssertNil(request.notes)
  }

  func testUpdateRequest_NonEmptyNotes_Preserved() {
    var editData = OfferEditData()
    editData.notes = "Important notes"
    let request = OfferUpdateRequest(from: editData)
    XCTAssertEqual(request.notes, "Important notes")
  }

  func testUpdateRequest_Codable_SnakeCaseKeys() throws {
    var editData = OfferEditData()
    editData.offerType = .partial
    editData.scholarshipAmount = 15000
    editData.scholarshipPercentage = 50
    let request = OfferUpdateRequest(from: editData)

    let data = try JSONEncoder().encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    XCTAssertNotNil(json["offer_type"])
    XCTAssertNotNil(json["scholarship_amount"])
    XCTAssertNotNil(json["scholarship_percentage"])
    XCTAssertNotNil(json["offer_date"])
  }

  // MARK: - Helpers

  private func makeOffer(
    deadlineDate: String? = nil,
    conditions: String? = nil,
    notes: String? = nil
  ) -> Offer {
    Offer(
      id: "offer-1",
      userId: "user-1",
      schoolId: "school-1",
      offerType: .scholarship,
      scholarshipAmount: nil,
      scholarshipPercentage: nil,
      offerDate: "2025-06-01",
      deadlineDate: deadlineDate,
      status: .pending,
      conditions: conditions,
      notes: notes,
      createdAt: "2025-06-01T00:00:00Z",
      updatedAt: "2025-06-01T00:00:00Z"
    )
  }
}
