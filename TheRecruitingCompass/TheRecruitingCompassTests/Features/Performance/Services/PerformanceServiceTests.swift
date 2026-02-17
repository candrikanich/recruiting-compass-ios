import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PerformanceServiceTests: XCTestCase {
  var mockService: MockPerformanceService!

  override func setUp() {
    mockService = MockPerformanceService()
  }

  override func tearDown() {
    mockService = nil
  }

  // MARK: - Fetch Metrics Tests

  func testFetchMetrics_ReturnsAllMetrics() async throws {
    // Given
    mockService.mockMetrics = [
      mockService.createTestMetric(id: "1", metricType: .velocity, value: 90.0),
      mockService.createTestMetric(id: "2", metricType: .exitVelo, value: 105.0),
      mockService.createTestMetric(id: "3", metricType: .sixtyTime, value: 6.8)
    ]

    // When
    let result = try await mockService.fetchMetrics(userId: "user-1")

    // Then
    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(mockService.fetchMetricsCallCount, 1)
    XCTAssertEqual(mockService.lastFetchUserId, "user-1")
  }

  func testFetchMetrics_EmptyResult() async throws {
    // Given
    mockService.mockMetrics = []

    // When
    let result = try await mockService.fetchMetrics(userId: "user-1")

    // Then
    XCTAssertTrue(result.isEmpty)
  }

  func testFetchMetrics_ThrowsError_WhenServiceFails() async {
    // Given
    mockService.shouldSucceed = false

    // When/Then
    do {
      _ = try await mockService.fetchMetrics(userId: "user-1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
      XCTAssertEqual(mockService.fetchMetricsCallCount, 1)
    }
  }

  func testFetchMetrics_TracksUserId() async throws {
    // Given
    mockService.mockMetrics = []

    // When
    _ = try await mockService.fetchMetrics(userId: "specific-user-id")

    // Then
    XCTAssertEqual(mockService.lastFetchUserId, "specific-user-id")
  }

  // MARK: - Create Metric Tests

  func testCreateMetric_Success() async throws {
    // Given
    let request = MetricCreateRequest(
      metricType: "velocity",
      value: 92.5,
      unit: "mph",
      recordedDate: "2026-02-15",
      verified: false,
      notes: nil
    )

    // When
    let result = try await mockService.createMetric(userId: "user-1", request: request)

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result.value, 92.5)
    XCTAssertEqual(mockService.createMetricCallCount, 1)
    XCTAssertEqual(mockService.lastCreateUserId, "user-1")
    XCTAssertNotNil(mockService.lastCreateRequest)
    XCTAssertEqual(mockService.lastCreateRequest?.metricType, "velocity")
  }

  func testCreateMetric_UsesProvidedMock() async throws {
    // Given
    let mockMetric = mockService.createTestMetric(
      id: "custom-id",
      metricType: .exitVelo,
      value: 110.0,
      unit: "mph"
    )
    mockService.mockCreatedMetric = mockMetric

    let request = MetricCreateRequest(
      metricType: "exit_velo",
      value: 110.0,
      unit: "mph",
      recordedDate: "2026-02-15",
      verified: true,
      notes: "BP session"
    )

    // When
    let result = try await mockService.createMetric(userId: "user-1", request: request)

    // Then
    XCTAssertEqual(result.id, "custom-id")
    XCTAssertEqual(result.metricType, .exitVelo)
    XCTAssertEqual(result.value, 110.0)
  }

  func testCreateMetric_ThrowsError_WhenServiceFails() async {
    // Given
    mockService.shouldSucceed = false
    let request = MetricCreateRequest(
      metricType: "velocity",
      value: 90.0,
      unit: "mph",
      recordedDate: "2026-02-15",
      verified: false,
      notes: nil
    )

    // When/Then
    do {
      _ = try await mockService.createMetric(userId: "user-1", request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
      XCTAssertEqual(mockService.createMetricCallCount, 1)
    }
  }

  func testCreateMetric_WithNotes() async throws {
    // Given
    let request = MetricCreateRequest(
      metricType: "era",
      value: 2.50,
      unit: "era",
      recordedDate: "2026-02-15",
      verified: true,
      notes: "Season ERA after 10 games"
    )

    // When
    let result = try await mockService.createMetric(userId: "user-1", request: request)

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(mockService.lastCreateRequest?.notes, "Season ERA after 10 games")
    XCTAssertEqual(mockService.lastCreateRequest?.verified, true)
  }

  // MARK: - Update Metric Tests

  func testUpdateMetric_Success() async throws {
    // Given
    let existing = mockService.createTestMetric(id: "metric-1", value: 90.0)
    mockService.mockMetrics = [existing]

    let request = MetricUpdateRequest(
      metricType: nil,
      value: 95.0,
      unit: nil,
      recordedDate: nil,
      verified: nil,
      notes: "Updated value"
    )

    // When
    let result = try await mockService.updateMetric(id: "metric-1", request: request)

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(mockService.updateMetricCallCount, 1)
    XCTAssertEqual(mockService.lastUpdateId, "metric-1")
    XCTAssertEqual(mockService.lastUpdateRequest?.value, 95.0)
  }

  func testUpdateMetric_UsesProvidedMock() async throws {
    // Given
    let updatedMetric = mockService.createTestMetric(id: "metric-1", value: 97.0)
    mockService.mockUpdatedMetric = updatedMetric

    let request = MetricUpdateRequest(
      metricType: nil,
      value: 97.0,
      unit: nil,
      recordedDate: nil,
      verified: nil,
      notes: nil
    )

    // When
    let result = try await mockService.updateMetric(id: "metric-1", request: request)

    // Then
    XCTAssertEqual(result.value, 97.0)
  }

  func testUpdateMetric_ThrowsError_WhenServiceFails() async {
    // Given
    mockService.shouldSucceed = false
    let request = MetricUpdateRequest(
      metricType: nil,
      value: 95.0,
      unit: nil,
      recordedDate: nil,
      verified: nil,
      notes: nil
    )

    // When/Then
    do {
      _ = try await mockService.updateMetric(id: "metric-1", request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
      XCTAssertEqual(mockService.updateMetricCallCount, 1)
    }
  }

  func testUpdateMetric_NotFound_ThrowsError() async {
    // Given - no metrics in mock
    mockService.mockMetrics = []

    let request = MetricUpdateRequest(
      metricType: nil,
      value: 95.0,
      unit: nil,
      recordedDate: nil,
      verified: nil,
      notes: nil
    )

    // When/Then
    do {
      _ = try await mockService.updateMetric(id: "nonexistent", request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.code, 404)
    }
  }

  // MARK: - Delete Metric Tests

  func testDeleteMetric_Success() async throws {
    // Given
    mockService.mockMetrics = [
      mockService.createTestMetric(id: "metric-1"),
      mockService.createTestMetric(id: "metric-2")
    ]

    // When
    try await mockService.deleteMetric(id: "metric-1")

    // Then
    XCTAssertEqual(mockService.deleteMetricCallCount, 1)
    XCTAssertEqual(mockService.lastDeletedId, "metric-1")
    XCTAssertEqual(mockService.mockMetrics.count, 1)
    XCTAssertFalse(mockService.mockMetrics.contains(where: { $0.id == "metric-1" }))
  }

  func testDeleteMetric_ThrowsError_WhenServiceFails() async {
    // Given
    mockService.shouldSucceed = false

    // When/Then
    do {
      try await mockService.deleteMetric(id: "metric-1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
      XCTAssertEqual(mockService.deleteMetricCallCount, 1)
    }
  }

  func testDeleteMetric_RemovesFromList() async throws {
    // Given
    mockService.mockMetrics = [
      mockService.createTestMetric(id: "keep"),
      mockService.createTestMetric(id: "delete-me"),
      mockService.createTestMetric(id: "also-keep")
    ]

    // When
    try await mockService.deleteMetric(id: "delete-me")

    // Then
    XCTAssertEqual(mockService.mockMetrics.count, 2)
    XCTAssertTrue(mockService.mockMetrics.contains(where: { $0.id == "keep" }))
    XCTAssertTrue(mockService.mockMetrics.contains(where: { $0.id == "also-keep" }))
    XCTAssertFalse(mockService.mockMetrics.contains(where: { $0.id == "delete-me" }))
  }

  // MARK: - Reset Tests

  func testReset_ClearsAllState() {
    // Given
    mockService.mockMetrics = [mockService.createTestMetric(id: "1")]
    mockService.fetchMetricsCallCount = 5
    mockService.createMetricCallCount = 3
    mockService.updateMetricCallCount = 2
    mockService.deleteMetricCallCount = 1
    mockService.lastFetchUserId = "user-1"
    mockService.lastCreateUserId = "user-1"
    mockService.lastUpdateId = "metric-1"
    mockService.lastDeletedId = "metric-1"

    // When
    mockService.reset()

    // Then
    XCTAssertTrue(mockService.mockMetrics.isEmpty)
    XCTAssertNil(mockService.mockCreatedMetric)
    XCTAssertNil(mockService.mockUpdatedMetric)
    XCTAssertTrue(mockService.shouldSucceed)
    XCTAssertEqual(mockService.fetchMetricsCallCount, 0)
    XCTAssertEqual(mockService.createMetricCallCount, 0)
    XCTAssertEqual(mockService.updateMetricCallCount, 0)
    XCTAssertEqual(mockService.deleteMetricCallCount, 0)
    XCTAssertNil(mockService.lastFetchUserId)
    XCTAssertNil(mockService.lastCreateUserId)
    XCTAssertNil(mockService.lastCreateRequest)
    XCTAssertNil(mockService.lastUpdateId)
    XCTAssertNil(mockService.lastUpdateRequest)
    XCTAssertNil(mockService.lastDeletedId)
  }

  // MARK: - Multiple Operations Tests

  func testMultipleOperations_TrackCallCounts() async throws {
    // Given
    mockService.mockMetrics = [mockService.createTestMetric(id: "1")]

    // When
    _ = try await mockService.fetchMetrics(userId: "user-1")
    _ = try await mockService.fetchMetrics(userId: "user-1")
    _ = try await mockService.createMetric(
      userId: "user-1",
      request: MetricCreateRequest(
        metricType: "velocity",
        value: 90.0,
        unit: "mph",
        recordedDate: "2026-02-15",
        verified: false,
        notes: nil
      )
    )

    // Then
    XCTAssertEqual(mockService.fetchMetricsCallCount, 2)
    XCTAssertEqual(mockService.createMetricCallCount, 1)
    XCTAssertEqual(mockService.updateMetricCallCount, 0)
    XCTAssertEqual(mockService.deleteMetricCallCount, 0)
  }
}
