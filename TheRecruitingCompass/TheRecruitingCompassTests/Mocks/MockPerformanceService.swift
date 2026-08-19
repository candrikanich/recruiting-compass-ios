import Foundation
@testable import TheRecruitingCompass

final class MockPerformanceService: PerformanceManaging, @unchecked Sendable {
  // MARK: - Mock State

  var mockMetrics: [PerformanceMetric] = []
  var mockCreatedMetric: PerformanceMetric?
  var mockUpdatedMetric: PerformanceMetric?
  var shouldSucceed = true
  var mockError: Error = NSError(domain: "MockPerformanceService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock service error"])

  // MARK: - Call Tracking

  var fetchMetricsCallCount = 0
  var createMetricCallCount = 0
  var updateMetricCallCount = 0
  var setPrimaryMetricCallCount = 0
  var deleteMetricCallCount = 0

  var lastFetchUserId: String?
  var lastCreateUserId: String?
  var lastCreateRequest: MetricCreateRequest?
  var lastUpdateId: String?
  var lastUpdateRequest: MetricUpdateRequest?
  var lastSetPrimaryId: String?
  var lastDeletedId: String?

  // MARK: - PerformanceManaging Methods

  func fetchMetrics(userId: String) async throws -> [PerformanceMetric] {
    fetchMetricsCallCount += 1
    lastFetchUserId = userId

    if !shouldSucceed {
      throw mockError
    }

    return mockMetrics
  }

  func createMetric(userId: String, request: MetricCreateRequest) async throws -> PerformanceMetric {
    createMetricCallCount += 1
    lastCreateUserId = userId
    lastCreateRequest = request

    if !shouldSucceed {
      throw mockError
    }

    if let mock = mockCreatedMetric {
      return mock
    }

    return createTestMetric(
      metricType: MetricType(rawValue: request.metricType) ?? .other,
      value: request.value,
      unit: request.unit
    )
  }

  func updateMetric(id: String, request: MetricUpdateRequest) async throws -> PerformanceMetric {
    updateMetricCallCount += 1
    lastUpdateId = id
    lastUpdateRequest = request

    if !shouldSucceed {
      throw mockError
    }

    if let mock = mockUpdatedMetric {
      return mock
    }

    guard let existing = mockMetrics.first(where: { $0.id == id }) else {
      throw NSError(domain: "MockPerformanceService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Metric not found"])
    }
    return existing
  }

  func setPrimaryMetric(id: String) async throws {
    setPrimaryMetricCallCount += 1
    lastSetPrimaryId = id

    if !shouldSucceed {
      throw mockError
    }

    mockMetrics = mockMetrics.map { $0.withIsPrimary($0.id == id) }
  }

  func deleteMetric(id: String) async throws {
    deleteMetricCallCount += 1
    lastDeletedId = id

    if !shouldSucceed {
      throw mockError
    }

    mockMetrics.removeAll { $0.id == id }
  }

  // MARK: - Reset

  func reset() {
    mockMetrics = []
    mockCreatedMetric = nil
    mockUpdatedMetric = nil
    shouldSucceed = true

    fetchMetricsCallCount = 0
    createMetricCallCount = 0
    updateMetricCallCount = 0
    setPrimaryMetricCallCount = 0
    deleteMetricCallCount = 0

    lastFetchUserId = nil
    lastCreateUserId = nil
    lastCreateRequest = nil
    lastUpdateId = nil
    lastUpdateRequest = nil
    lastSetPrimaryId = nil
    lastDeletedId = nil
  }

  // MARK: - Test Helpers

  func createTestMetric(
    id: String = UUID().uuidString,
    userId: String = "test-user-id",
    metricType: MetricType = .velocity,
    value: Double = 90.0,
    unit: String = "mph",
    recordedDate: Date = Date(),
    eventId: String? = nil,
    verified: Bool = false,
    notes: String? = nil,
    isPrimary: Bool = false,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> PerformanceMetric {
    PerformanceMetric(
      id: id,
      userId: userId,
      metricType: metricType,
      value: value,
      unit: unit,
      recordedDate: recordedDate,
      eventId: eventId,
      verified: verified,
      notes: notes,
      isPrimary: isPrimary,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
