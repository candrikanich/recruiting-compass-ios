import Foundation
@testable import TheRecruitingCompass

final class MockEventsService: EventsManaging, @unchecked Sendable {
  // MARK: - Call Counts

  var createEventCallCount = 0
  var fetchEventCallCount = 0
  var fetchEventsCallCount = 0
  var fetchSchoolsCallCount = 0
  var createSchoolCallCount = 0
  var updateEventCallCount = 0
  var deleteEventCallCount = 0
  var fetchCoachesCallCount = 0
  var fetchMetricsCallCount = 0
  var createMetricCallCount = 0
  var deleteMetricCallCount = 0
  var createInteractionCallCount = 0

  // MARK: - Captured Arguments

  var lastCreateEventRequest: CreateEventRequest?
  var lastFetchEventId: String?
  var lastFetchEventUserId: String?
  var lastFetchEventsUserId: String?
  var lastFetchSchoolsFamilyUnitId: String?
  var lastCreateSchoolName: String?
  var lastCreateSchoolLocation: String?
  var lastCreateSchoolUserId: String?
  var lastCreateSchoolFamilyUnitId: String?
  var lastUpdateEventId: String?
  var lastUpdateEventRequest: EventUpdateRequest?
  var lastDeleteEventId: String?
  var lastFetchCoachesSchoolId: String?
  var lastFetchMetricsEventId: String?
  var lastCreateMetricRequest: CreateMetricRequest?
  var lastDeleteMetricId: String?
  var lastCreateInteractionRequest: CreateInteractionRequest?

  // MARK: - Error Flags

  var shouldThrowCreateEvent = false
  var shouldThrowFetchEvent = false
  /// When shouldThrowFetchEvent is true, use this code (404 = not found, others = generic error).
  var fetchEventErrorCode = 404
  var shouldThrowFetchEvents = false
  var shouldThrowFetchSchools = false
  var shouldThrowCreateSchool = false
  var shouldThrowUpdateEvent = false
  var shouldThrowDeleteEvent = false
  var shouldThrowFetchCoaches = false
  var shouldThrowFetchMetrics = false
  var shouldThrowCreateMetric = false
  var shouldThrowDeleteMetric = false
  var shouldThrowCreateInteraction = false

  var shouldThrowError: Bool {
    get { shouldThrowCreateEvent }
    set {
      shouldThrowCreateEvent = newValue
      shouldThrowFetchEvent = newValue
      shouldThrowFetchEvents = newValue
      shouldThrowFetchSchools = newValue
      shouldThrowCreateSchool = newValue
      shouldThrowUpdateEvent = newValue
      shouldThrowDeleteEvent = newValue
      shouldThrowFetchCoaches = newValue
      shouldThrowFetchMetrics = newValue
      shouldThrowCreateMetric = newValue
      shouldThrowDeleteMetric = newValue
      shouldThrowCreateInteraction = newValue
    }
  }

  // MARK: - Stubbed Results

  var stubbedCreatedEvent = FullEvent.mock()
  var stubbedFetchedEvent = FullEvent.mock()
  var stubbedUpdatedEvent = FullEvent.mock()
  var stubbedEvents: [FullEvent] = []
  var stubbedSchools: [SchoolSummary] = []
  var stubbedCreatedSchool = SchoolSummary(id: "new-school-1", name: "New School", location: nil)
  var stubbedCoaches: [Coach] = []
  var stubbedMetrics: [PerformanceMetric] = []
  var stubbedCreatedMetric: PerformanceMetric?

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

  func fetchEvent(id: String, userId: String) async throws -> FullEvent {
    fetchEventCallCount += 1
    lastFetchEventId = id
    lastFetchEventUserId = userId
    if shouldThrowFetchEvent {
      let message = fetchEventErrorCode == 404 ? "Event not found" : "Mock fetch event error"
      throw NSError(
        domain: "MockEventsService",
        code: fetchEventErrorCode,
        userInfo: [NSLocalizedDescriptionKey: message]
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

  func fetchSchools(familyUnitId: String) async throws -> [SchoolSummary] {
    fetchSchoolsCallCount += 1
    lastFetchSchoolsFamilyUnitId = familyUnitId
    if shouldThrowFetchSchools {
      throw NSError(
        domain: "MockEventsService",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Mock fetch schools error"]
      )
    }
    return stubbedSchools
  }

  func createSchool(name: String, location: String?, userId: String, familyUnitId: String) async throws -> SchoolSummary {
    createSchoolCallCount += 1
    lastCreateSchoolName = name
    lastCreateSchoolLocation = location
    lastCreateSchoolUserId = userId
    lastCreateSchoolFamilyUnitId = familyUnitId
    if shouldThrowCreateSchool {
      throw NSError(
        domain: "MockEventsService",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Mock create school error"]
      )
    }
    return stubbedCreatedSchool
  }

  func updateEvent(id: String, request: EventUpdateRequest) async throws -> FullEvent {
    updateEventCallCount += 1
    lastUpdateEventId = id
    lastUpdateEventRequest = request
    if shouldThrowUpdateEvent {
      throw NSError(
        domain: "MockEventsService",
        code: 6,
        userInfo: [NSLocalizedDescriptionKey: "Mock update event error"]
      )
    }
    return stubbedUpdatedEvent
  }

  func deleteEvent(id: String) async throws {
    deleteEventCallCount += 1
    lastDeleteEventId = id
    if shouldThrowDeleteEvent {
      throw NSError(
        domain: "MockEventsService",
        code: 7,
        userInfo: [NSLocalizedDescriptionKey: "Mock delete event error"]
      )
    }
  }

  func fetchCoaches(schoolId: String, userId: String) async throws -> [Coach] {
    fetchCoachesCallCount += 1
    lastFetchCoachesSchoolId = schoolId
    if shouldThrowFetchCoaches {
      throw NSError(
        domain: "MockEventsService",
        code: 8,
        userInfo: [NSLocalizedDescriptionKey: "Mock fetch coaches error"]
      )
    }
    return stubbedCoaches
  }

  func fetchMetrics(eventId: String, userId: String) async throws -> [PerformanceMetric] {
    fetchMetricsCallCount += 1
    lastFetchMetricsEventId = eventId
    if shouldThrowFetchMetrics {
      throw NSError(
        domain: "MockEventsService",
        code: 9,
        userInfo: [NSLocalizedDescriptionKey: "Mock fetch metrics error"]
      )
    }
    return stubbedMetrics
  }

  func createMetric(_ request: CreateMetricRequest) async throws -> PerformanceMetric {
    createMetricCallCount += 1
    lastCreateMetricRequest = request
    if shouldThrowCreateMetric {
      throw NSError(
        domain: "MockEventsService",
        code: 10,
        userInfo: [NSLocalizedDescriptionKey: "Mock create metric error"]
      )
    }
    return stubbedCreatedMetric!
  }

  func deleteMetric(id: String) async throws {
    deleteMetricCallCount += 1
    lastDeleteMetricId = id
    if shouldThrowDeleteMetric {
      throw NSError(
        domain: "MockEventsService",
        code: 12,
        userInfo: [NSLocalizedDescriptionKey: "Mock delete metric error"]
      )
    }
  }

  func createInteraction(_ request: CreateInteractionRequest) async throws {
    createInteractionCallCount += 1
    lastCreateInteractionRequest = request
    if shouldThrowCreateInteraction {
      throw NSError(
        domain: "MockEventsService",
        code: 11,
        userInfo: [NSLocalizedDescriptionKey: "Mock create interaction error"]
      )
    }
  }
}

// MARK: - Test Helpers

extension FullEvent {
  static func mock(
    id: String = "event-1",
    name: String = "Spring Showcase 2026",
    type: String = "showcase",
    startDate: String = "2026-04-15",
    userId: String = "test-user-id",
    schoolId: String? = nil,
    attended: Bool = false,
    coachesPresent: [String]? = nil
  ) -> FullEvent {
    FullEvent(
      id: id,
      name: name,
      type: type,
      schoolId: schoolId,
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
      attended: attended,
      performanceNotes: nil,
      userId: userId,
      createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: coachesPresent,
      updatedAt: "2026-02-17T00:00:00Z"
    )
  }
}
