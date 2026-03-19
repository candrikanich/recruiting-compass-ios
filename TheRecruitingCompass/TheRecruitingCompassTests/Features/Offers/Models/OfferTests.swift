import XCTest
@testable import TheRecruitingCompass

@MainActor
final class OfferTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Test Helpers

  private func makeOffer(
    deadlineDate: String? = nil,
    scholarshipAmount: Double? = nil,
    scholarshipPercentage: Int? = nil,
    offerDate: String = "2025-06-01"
  ) -> Offer {
    Offer(
      id: "offer-1",
      userId: "user-1",
      schoolId: "school-1",
      offerType: .scholarship,
      scholarshipAmount: scholarshipAmount,
      scholarshipPercentage: scholarshipPercentage,
      offerDate: offerDate,
      deadlineDate: deadlineDate,
      status: .pending,
      conditions: nil,
      notes: nil,
      createdAt: "2025-06-01T00:00:00Z",
      updatedAt: "2025-06-01T00:00:00Z"
    )
  }

  // MARK: - daysUntilDeadline Tests

  func testDaysUntilDeadline_NilWhenNoDeadline() {
    let offer = makeOffer(deadlineDate: nil)
    XCTAssertNil(offer.daysUntilDeadline)
  }

  func testDaysUntilDeadline_PositiveForFutureDate() {
    let utc = TimeZone(identifier: "UTC")!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = utc
    let startOfTodayUTC = cal.startOfDay(for: Date())
    let futureDate = cal.date(byAdding: .day, value: 15, to: startOfTodayUTC)!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = utc
    let offer = makeOffer(deadlineDate: formatter.string(from: futureDate))

    let days = offer.daysUntilDeadline
    XCTAssertNotNil(days)
    XCTAssertEqual(days, 15)
  }

  func testDaysUntilDeadline_NegativeForPastDate() {
    let utc = TimeZone(identifier: "UTC")!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = utc
    let startOfTodayUTC = cal.startOfDay(for: Date())
    let pastDate = cal.date(byAdding: .day, value: -5, to: startOfTodayUTC)!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = utc
    let offer = makeOffer(deadlineDate: formatter.string(from: pastDate))

    let days = offer.daysUntilDeadline
    XCTAssertNotNil(days)
    XCTAssertEqual(days, -5)
  }

  func testDaysUntilDeadline_ZeroForToday() {
    let utc = TimeZone(identifier: "UTC")!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = utc
    let startOfTodayUTC = cal.startOfDay(for: Date())
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = utc
    let offer = makeOffer(deadlineDate: formatter.string(from: startOfTodayUTC))

    let days = offer.daysUntilDeadline
    XCTAssertNotNil(days)
    XCTAssertEqual(days, 0)
  }

  // MARK: - deadlineUrgency Tests

  func testDeadlineUrgency_NoneWhenNoDeadline() {
    let offer = makeOffer(deadlineDate: nil)
    XCTAssertEqual(offer.deadlineUrgency, .none)
  }

  func testDeadlineUrgency_OverdueWhenPast() {
    let pastDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let offer = makeOffer(deadlineDate: formatter.string(from: pastDate))

    XCTAssertEqual(offer.deadlineUrgency, .overdue)
  }

  func testDeadlineUrgency_CriticalWithin7Days() {
    let soonDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let offer = makeOffer(deadlineDate: formatter.string(from: soonDate))

    XCTAssertEqual(offer.deadlineUrgency, .critical)
  }

  func testDeadlineUrgency_CriticalAtExactly7Days() {
    let date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let offer = makeOffer(deadlineDate: formatter.string(from: date))

    XCTAssertEqual(offer.deadlineUrgency, .critical)
  }

  func testDeadlineUrgency_UrgentWithin30Days() {
    let date = Calendar.current.date(byAdding: .day, value: 20, to: Date())!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let offer = makeOffer(deadlineDate: formatter.string(from: date))

    XCTAssertEqual(offer.deadlineUrgency, .urgent)
  }

  func testDeadlineUrgency_UrgentAtExactly30Days() {
    let date = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let offer = makeOffer(deadlineDate: formatter.string(from: date))

    XCTAssertEqual(offer.deadlineUrgency, .urgent)
  }

  func testDeadlineUrgency_NormalBeyond30Days() {
    let date = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let offer = makeOffer(deadlineDate: formatter.string(from: date))

    XCTAssertEqual(offer.deadlineUrgency, .normal)
  }

  // MARK: - formattedAmount Tests

  func testFormattedAmount_NilWhenNoAmount() {
    let offer = makeOffer(scholarshipAmount: nil)
    XCTAssertNil(offer.formattedAmount)
  }

  func testFormattedAmount_NilWhenZero() {
    let offer = makeOffer(scholarshipAmount: 0)
    XCTAssertNil(offer.formattedAmount)
  }

  func testFormattedAmount_FormattedWhenPositive() {
    let offer = makeOffer(scholarshipAmount: 25000)
    let formatted = offer.formattedAmount
    XCTAssertNotNil(formatted)
    XCTAssertTrue(formatted!.contains("25,000"))
  }

  func testFormattedAmount_NilWhenNegative() {
    let offer = makeOffer(scholarshipAmount: -100)
    XCTAssertNil(offer.formattedAmount)
  }

  // MARK: - formattedPercentage Tests

  func testFormattedPercentage_NilWhenNoPercentage() {
    let offer = makeOffer(scholarshipPercentage: nil)
    XCTAssertNil(offer.formattedPercentage)
  }

  func testFormattedPercentage_NilWhenZero() {
    let offer = makeOffer(scholarshipPercentage: 0)
    XCTAssertNil(offer.formattedPercentage)
  }

  func testFormattedPercentage_FormattedWhenPositive() {
    let offer = makeOffer(scholarshipPercentage: 75)
    XCTAssertEqual(offer.formattedPercentage, "75%")
  }

  func testFormattedPercentage_100Percent() {
    let offer = makeOffer(scholarshipPercentage: 100)
    XCTAssertEqual(offer.formattedPercentage, "100%")
  }

  // MARK: - parseDate Tests

  func testParseDate_ISO8601WithFractionalSeconds() {
    let date = Offer.parseDate("2025-06-15T14:30:00.000Z")
    XCTAssertNotNil(date)
  }

  func testParseDate_ISO8601WithoutFractionalSeconds() {
    let date = Offer.parseDate("2025-06-15T14:30:00Z")
    XCTAssertNotNil(date)
  }

  func testParseDate_DateOnly() {
    let date = Offer.parseDate("2025-06-15")
    XCTAssertNotNil(date)
  }

  func testParseDate_InvalidString() {
    let date = Offer.parseDate("not-a-date")
    XCTAssertNil(date)
  }

  func testParseDate_EmptyString() {
    let date = Offer.parseDate("")
    XCTAssertNil(date)
  }

  // MARK: - displayOfferDate Tests

  func testDisplayOfferDate_ReturnsValidDate() {
    let offer = makeOffer(offerDate: "2025-06-15")
    let expected = Offer.parseDate("2025-06-15")
    XCTAssertEqual(offer.displayOfferDate, expected)
  }

  // MARK: - displayDeadlineDate Tests

  func testDisplayDeadlineDate_NilWhenNoDeadline() {
    let offer = makeOffer(deadlineDate: nil)
    XCTAssertNil(offer.displayDeadlineDate)
  }

  func testDisplayDeadlineDate_ReturnsDateWhenPresent() {
    let offer = makeOffer(deadlineDate: "2025-12-31")
    XCTAssertNotNil(offer.displayDeadlineDate)
  }

  // MARK: - Codable Round-Trip Tests

  func testCodable_RoundTrip() throws {
    let offer = Offer(
      id: "test-id",
      userId: "user-1",
      schoolId: "school-1",
      offerType: .fullRide,
      scholarshipAmount: 50000,
      scholarshipPercentage: 100,
      offerDate: "2025-06-01",
      deadlineDate: "2025-12-31",
      status: .accepted,
      conditions: "Must maintain 3.0 GPA",
      notes: "Great opportunity",
      createdAt: "2025-06-01T00:00:00Z",
      updatedAt: "2025-06-01T00:00:00Z"
    )

    let encoded = try JSONEncoder().encode(offer)
    let decoded = try JSONDecoder().decode(Offer.self, from: encoded)

    XCTAssertEqual(decoded.id, offer.id)
    XCTAssertEqual(decoded.userId, offer.userId)
    XCTAssertEqual(decoded.schoolId, offer.schoolId)
    XCTAssertEqual(decoded.offerType, offer.offerType)
    XCTAssertEqual(decoded.scholarshipAmount, offer.scholarshipAmount)
    XCTAssertEqual(decoded.scholarshipPercentage, offer.scholarshipPercentage)
    XCTAssertEqual(decoded.offerDate, offer.offerDate)
    XCTAssertEqual(decoded.deadlineDate, offer.deadlineDate)
    XCTAssertEqual(decoded.status, offer.status)
    XCTAssertEqual(decoded.conditions, offer.conditions)
    XCTAssertEqual(decoded.notes, offer.notes)
  }

  func testCodable_SnakeCaseKeys() throws {
    let json = """
    {
      "id": "1",
      "user_id": "user-1",
      "school_id": "school-1",
      "offer_type": "full_ride",
      "scholarship_amount": 25000,
      "scholarship_percentage": 75,
      "offer_date": "2025-06-01",
      "deadline_date": "2025-12-31",
      "status": "pending",
      "conditions": null,
      "notes": "Test",
      "created_at": "2025-06-01T00:00:00Z",
      "updated_at": "2025-06-01T00:00:00Z"
    }
    """

    let data = json.data(using: .utf8)!
    let offer = try JSONDecoder().decode(Offer.self, from: data)

    XCTAssertEqual(offer.id, "1")
    XCTAssertEqual(offer.userId, "user-1")
    XCTAssertEqual(offer.schoolId, "school-1")
    XCTAssertEqual(offer.offerType, .fullRide)
    XCTAssertEqual(offer.scholarshipAmount, 25000)
    XCTAssertEqual(offer.scholarshipPercentage, 75)
    XCTAssertEqual(offer.deadlineDate, "2025-12-31")
    XCTAssertEqual(offer.status, .pending)
    XCTAssertEqual(offer.notes, "Test")
  }

  func testCodable_NilOptionalFields() throws {
    let offer = makeOffer(
      deadlineDate: nil,
      scholarshipAmount: nil,
      scholarshipPercentage: nil
    )

    let encoded = try JSONEncoder().encode(offer)
    let decoded = try JSONDecoder().decode(Offer.self, from: encoded)

    XCTAssertNil(decoded.scholarshipAmount)
    XCTAssertNil(decoded.scholarshipPercentage)
    XCTAssertNil(decoded.deadlineDate)
  }
}
