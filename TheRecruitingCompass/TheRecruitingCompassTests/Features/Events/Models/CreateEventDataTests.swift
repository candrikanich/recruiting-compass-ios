import XCTest
@testable import TheRecruitingCompass

final class CreateEventDataTests: XCTestCase {

  // MARK: - Default Values

  func testDefaultValues_allFieldsAreEmpty() {
    let data = CreateEventData()

    XCTAssertNil(data.type)
    XCTAssertEqual(data.name, "")
    XCTAssertEqual(data.startDate, "")
    XCTAssertEqual(data.endDate, "")
    XCTAssertEqual(data.startTime, "")
    XCTAssertEqual(data.endTime, "")
    XCTAssertEqual(data.checkinTime, "")
    XCTAssertNil(data.schoolId)
    XCTAssertEqual(data.location, "")
    XCTAssertEqual(data.address, "")
    XCTAssertEqual(data.city, "")
    XCTAssertEqual(data.state, "")
    XCTAssertEqual(data.url, "")
    XCTAssertEqual(data.description, "")
    XCTAssertNil(data.eventSource)
    XCTAssertEqual(data.cost, "")
    XCTAssertFalse(data.registered)
    XCTAssertFalse(data.attended)
    XCTAssertEqual(data.performanceNotes, "")
  }

  // MARK: - CreateEventRequest Conversion

  func testCreateEventRequest_from_fullData() {
    var data = CreateEventData()
    data.type = .showcase
    data.name = "  Spring Showcase  "
    data.startDate = "2026-04-15"
    data.endDate = "2026-04-16"
    data.startTime = "09:00"
    data.endTime = "17:00"
    data.checkinTime = "08:30"
    data.schoolId = "school-1"
    data.location = "Main Stadium"
    data.address = "123 Main St"
    data.city = "Atlanta"
    data.state = "ga"
    data.url = "https://example.com"
    data.description = "Annual showcase"
    data.eventSource = .email
    data.cost = "150"
    data.registered = true
    data.attended = false
    data.performanceNotes = "Good performance"

    let request = CreateEventRequest.from(formData: data, userId: "user-1")

    XCTAssertEqual(request.type, "showcase")
    XCTAssertEqual(request.name, "Spring Showcase")
    XCTAssertEqual(request.startDate, "2026-04-15")
    XCTAssertEqual(request.endDate, "2026-04-16")
    XCTAssertEqual(request.startTime, "09:00")
    XCTAssertEqual(request.endTime, "17:00")
    XCTAssertEqual(request.checkinTime, "08:30")
    XCTAssertEqual(request.schoolId, "school-1")
    XCTAssertEqual(request.location, "Main Stadium")
    XCTAssertEqual(request.address, "123 Main St")
    XCTAssertEqual(request.city, "Atlanta")
    XCTAssertEqual(request.state, "GA")
    XCTAssertEqual(request.url, "https://example.com")
    XCTAssertEqual(request.description, "Annual showcase")
    XCTAssertEqual(request.eventSource, "email")
    XCTAssertEqual(request.cost, 150.0)
    XCTAssertTrue(request.registered)
    XCTAssertFalse(request.attended)
    XCTAssertEqual(request.performanceNotes, "Good performance")
    XCTAssertEqual(request.userId, "user-1")
  }

  func testCreateEventRequest_from_emptyOptionals_convertToNil() {
    var data = CreateEventData()
    data.type = .camp
    data.name = "Test"
    data.startDate = "2026-06-01"

    let request = CreateEventRequest.from(formData: data, userId: "user-1")

    XCTAssertNil(request.endDate)
    XCTAssertNil(request.startTime)
    XCTAssertNil(request.endTime)
    XCTAssertNil(request.checkinTime)
    XCTAssertNil(request.schoolId)
    XCTAssertNil(request.location)
    XCTAssertNil(request.address)
    XCTAssertNil(request.city)
    XCTAssertNil(request.state)
    XCTAssertNil(request.url)
    XCTAssertNil(request.description)
    XCTAssertNil(request.eventSource)
    XCTAssertNil(request.cost)
    XCTAssertNil(request.performanceNotes)
  }

  func testCreateEventRequest_from_trimsName() {
    var data = CreateEventData()
    data.type = .game
    data.name = "  Game Day  "
    data.startDate = "2026-09-01"

    let request = CreateEventRequest.from(formData: data, userId: "user-1")

    XCTAssertEqual(request.name, "Game Day")
  }

  func testCreateEventRequest_from_uppercasesState() {
    var data = CreateEventData()
    data.type = .showcase
    data.name = "Test"
    data.startDate = "2026-04-15"
    data.state = "ga"

    let request = CreateEventRequest.from(formData: data, userId: "user-1")

    XCTAssertEqual(request.state, "GA")
  }

  func testCreateEventRequest_from_invalidCost_returnsNil() {
    var data = CreateEventData()
    data.type = .showcase
    data.name = "Test"
    data.startDate = "2026-04-15"
    data.cost = "not-a-number"

    let request = CreateEventRequest.from(formData: data, userId: "user-1")

    XCTAssertNil(request.cost)
  }

  func testCreateEventRequest_from_zeroCost_returnsZero() {
    var data = CreateEventData()
    data.type = .showcase
    data.name = "Free Event"
    data.startDate = "2026-04-15"
    data.cost = "0"

    let request = CreateEventRequest.from(formData: data, userId: "user-1")

    XCTAssertEqual(request.cost, 0.0)
  }

  // MARK: - EventType Tests

  func testEventType_allCases() {
    XCTAssertEqual(EventType.allCases.count, 5)
    XCTAssertTrue(EventType.allCases.contains(.showcase))
    XCTAssertTrue(EventType.allCases.contains(.camp))
    XCTAssertTrue(EventType.allCases.contains(.officialVisit))
    XCTAssertTrue(EventType.allCases.contains(.unofficialVisit))
    XCTAssertTrue(EventType.allCases.contains(.game))
  }

  func testEventType_rawValues() {
    XCTAssertEqual(EventType.showcase.rawValue, "showcase")
    XCTAssertEqual(EventType.camp.rawValue, "camp")
    XCTAssertEqual(EventType.officialVisit.rawValue, "official_visit")
    XCTAssertEqual(EventType.unofficialVisit.rawValue, "unofficial_visit")
    XCTAssertEqual(EventType.game.rawValue, "game")
  }

  func testEventType_displayNames() {
    XCTAssertEqual(EventType.showcase.displayName, "Showcase")
    XCTAssertEqual(EventType.camp.displayName, "Camp")
    XCTAssertEqual(EventType.officialVisit.displayName, "Official Visit")
    XCTAssertEqual(EventType.unofficialVisit.displayName, "Unofficial Visit")
    XCTAssertEqual(EventType.game.displayName, "Game")
  }

  // MARK: - EventSource Tests

  func testEventSource_allCases() {
    XCTAssertEqual(EventSource.allCases.count, 6)
  }

  func testEventSource_rawValues() {
    XCTAssertEqual(EventSource.email.rawValue, "email")
    XCTAssertEqual(EventSource.flyer.rawValue, "flyer")
    XCTAssertEqual(EventSource.webSearch.rawValue, "web_search")
    XCTAssertEqual(EventSource.recommendation.rawValue, "recommendation")
    XCTAssertEqual(EventSource.friend.rawValue, "friend")
    XCTAssertEqual(EventSource.other.rawValue, "other")
  }

  func testEventSource_displayNames() {
    XCTAssertEqual(EventSource.email.displayName, "Email")
    XCTAssertEqual(EventSource.flyer.displayName, "Flyer")
    XCTAssertEqual(EventSource.webSearch.displayName, "Web Search")
    XCTAssertEqual(EventSource.recommendation.displayName, "Recommendation")
    XCTAssertEqual(EventSource.friend.displayName, "Friend")
    XCTAssertEqual(EventSource.other.displayName, "Other")
  }

  // MARK: - FullEvent Model Tests

  func testFullEvent_isIdentifiable() {
    let event = FullEvent.mock(id: "test-id")
    XCTAssertEqual(event.id, "test-id")
  }

  func testFullEvent_decodesFromJSON() throws {
    let json = """
    {
      "id": "event-1",
      "name": "Test Event",
      "type": "showcase",
      "start_date": "2026-04-15",
      "registered": false,
      "attended": false,
      "user_id": "user-1",
      "created_at": "2026-02-17T00:00:00Z",
      "updated_at": "2026-02-17T00:00:00Z"
    }
    """.data(using: .utf8)!

    let event = try JSONDecoder().decode(FullEvent.self, from: json)

    XCTAssertEqual(event.id, "event-1")
    XCTAssertEqual(event.name, "Test Event")
    XCTAssertEqual(event.type, "showcase")
    XCTAssertEqual(event.startDate, "2026-04-15")
    XCTAssertEqual(event.userId, "user-1")
    XCTAssertNil(event.schoolId)
    XCTAssertNil(event.location)
    XCTAssertNil(event.cost)
  }

  func testFullEvent_decodesWithAllFields() throws {
    let json = """
    {
      "id": "event-1",
      "name": "Full Event",
      "type": "camp",
      "school_id": "school-1",
      "location": "Main Campus",
      "address": "123 Main St",
      "city": "Atlanta",
      "state": "GA",
      "start_date": "2026-06-01",
      "start_time": "09:00",
      "end_date": "2026-06-03",
      "end_time": "17:00",
      "checkin_time": "08:30",
      "url": "https://example.com",
      "description": "A camp",
      "event_source": "email",
      "cost": 250.50,
      "registered": true,
      "attended": true,
      "performance_notes": "Good",
      "user_id": "user-1",
      "created_at": "2026-02-17T00:00:00Z",
      "updated_at": "2026-02-17T00:00:00Z"
    }
    """.data(using: .utf8)!

    let event = try JSONDecoder().decode(FullEvent.self, from: json)

    XCTAssertEqual(event.schoolId, "school-1")
    XCTAssertEqual(event.location, "Main Campus")
    XCTAssertEqual(event.address, "123 Main St")
    XCTAssertEqual(event.city, "Atlanta")
    XCTAssertEqual(event.state, "GA")
    XCTAssertEqual(event.startTime, "09:00")
    XCTAssertEqual(event.endDate, "2026-06-03")
    XCTAssertEqual(event.endTime, "17:00")
    XCTAssertEqual(event.checkinTime, "08:30")
    XCTAssertEqual(event.url, "https://example.com")
    XCTAssertEqual(event.description, "A camp")
    XCTAssertEqual(event.eventSource, "email")
    XCTAssertEqual(event.cost, 250.50)
    XCTAssertTrue(event.registered)
    XCTAssertTrue(event.attended)
    XCTAssertEqual(event.performanceNotes, "Good")
  }

  // MARK: - SchoolSummary Tests

  func testSchoolSummary_isIdentifiable() {
    let summary = SchoolSummary(id: "s1", name: "Test", location: nil)
    XCTAssertEqual(summary.id, "s1")
  }

  func testSchoolSummary_decodesFromJSON() throws {
    let json = """
    {
      "id": "s1",
      "name": "Georgia Tech",
      "location": "Atlanta, GA"
    }
    """.data(using: .utf8)!

    let summary = try JSONDecoder().decode(SchoolSummary.self, from: json)

    XCTAssertEqual(summary.id, "s1")
    XCTAssertEqual(summary.name, "Georgia Tech")
    XCTAssertEqual(summary.location, "Atlanta, GA")
  }

  func testSchoolSummary_decodesWithNullLocation() throws {
    let json = """
    {
      "id": "s1",
      "name": "Unknown School",
      "location": null
    }
    """.data(using: .utf8)!

    let summary = try JSONDecoder().decode(SchoolSummary.self, from: json)

    XCTAssertNil(summary.location)
  }
}
