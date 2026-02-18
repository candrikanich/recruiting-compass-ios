import Foundation
@testable import TheRecruitingCompass

final class MockEventsService: EventsManaging, @unchecked Sendable {
  // MARK: - Call Counts

  var createEventCallCount = 0
  var fetchEventCallCount = 0
  var fetchEventsCallCount = 0
  var fetchSchoolsCallCount = 0
  var createSchoolCallCount = 0

  // MARK: - Captured Arguments

  var lastCreateEventRequest: CreateEventRequest?
  var lastFetchEventId: String?
  var lastFetchEventsUserId: String?
  var lastFetchSchoolsUserId: String?
  var lastCreateSchoolName: String?
  var lastCreateSchoolLocation: String?
  var lastCreateSchoolUserId: String?

  // MARK: - Error Flags

  var shouldThrowCreateEvent = false
  var shouldThrowFetchEvent = false
  var shouldThrowFetchEvents = false
  var shouldThrowFetchSchools = false
  var shouldThrowCreateSchool = false

  var shouldThrowError: Bool {
    get { shouldThrowCreateEvent }
    set {
      shouldThrowCreateEvent = newValue
      shouldThrowFetchEvent = newValue
      shouldThrowFetchEvents = newValue
      shouldThrowFetchSchools = newValue
      shouldThrowCreateSchool = newValue
    }
  }

  // MARK: - Stubbed Results

  var stubbedCreatedEvent = FullEvent.mock()
  var stubbedFetchedEvent = FullEvent.mock()
  var stubbedEvents: [FullEvent] = []
  var stubbedSchools: [SchoolSummary] = []
  var stubbedCreatedSchool = SchoolSummary(id: "new-school-1", name: "New School", location: nil)

  // MARK: - EventsManaging

  func createEvent(_ request: CreateEventRequest) async throws -> FullEvent {
    createEventCallCount += 1
    lastCreateEventRequest = request
    if shouldThrowCreateEvent {
      throw NSError(
        domain: "MockEventsService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Mock create event error"]
      )
    }
    return stubbedCreatedEvent
  }

  func fetchEvent(id: String) async throws -> FullEvent {
    fetchEventCallCount += 1
    lastFetchEventId = id
    if shouldThrowFetchEvent {
      throw NSError(
        domain: "MockEventsService",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Mock fetch event error"]
      )
    }
    return stubbedFetchedEvent
  }

  func fetchEvents(userId: String) async throws -> [FullEvent] {
    fetchEventsCallCount += 1
    lastFetchEventsUserId = userId
    if shouldThrowFetchEvents {
      throw NSError(
        domain: "MockEventsService",
        code: 5,
        userInfo: [NSLocalizedDescriptionKey: "Mock fetch events error"]
      )
    }
    return stubbedEvents
  }

  func fetchSchools(userId: String) async throws -> [SchoolSummary] {
    fetchSchoolsCallCount += 1
    lastFetchSchoolsUserId = userId
    if shouldThrowFetchSchools {
      throw NSError(
        domain: "MockEventsService",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Mock fetch schools error"]
      )
    }
    return stubbedSchools
  }

  func createSchool(name: String, location: String?, userId: String) async throws -> SchoolSummary {
    createSchoolCallCount += 1
    lastCreateSchoolName = name
    lastCreateSchoolLocation = location
    lastCreateSchoolUserId = userId
    if shouldThrowCreateSchool {
      throw NSError(
        domain: "MockEventsService",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Mock create school error"]
      )
    }
    return stubbedCreatedSchool
  }
}

// MARK: - Test Helpers

extension FullEvent {
  static func mock(
    id: String = "event-1",
    name: String = "Spring Showcase 2026",
    type: String = "showcase",
    startDate: String = "2026-04-15",
    userId: String = "test-user-id"
  ) -> FullEvent {
    FullEvent(
      id: id,
      name: name,
      type: type,
      schoolId: nil,
      location: nil,
      address: nil,
      city: nil,
      state: nil,
      startDate: startDate,
      startTime: nil,
      endDate: nil,
      endTime: nil,
      checkinTime: nil,
      url: nil,
      description: nil,
      eventSource: nil,
      cost: nil,
      registered: false,
      attended: false,
      performanceNotes: nil,
      userId: userId,
      createdAt: "2026-02-17T00:00:00Z",
      updatedAt: "2026-02-17T00:00:00Z"
    )
  }
}
