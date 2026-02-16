import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PerformanceDashboardViewModelTests: XCTestCase {
  var viewModel: PerformanceDashboardViewModel!
  var mockService: MockPerformanceService!
  var mockAuthManager: MockAuthManager!

  override func setUp() async throws {
    mockService = MockPerformanceService()
    mockAuthManager = MockAuthManager()
    mockAuthManager.user = createUser(id: "user-1")

    viewModel = PerformanceDashboardViewModel(
      performanceService: mockService,
      authManager: mockAuthManager
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    mockAuthManager = nil
  }

  // MARK: - Initialization Tests

  func testInit_DefaultState() {
    XCTAssertTrue(viewModel.metrics.isEmpty)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.showAddForm)
    XCTAssertFalse(viewModel.showEditSheet)
    XCTAssertNil(viewModel.editingMetric)
    XCTAssertFalse(viewModel.showExportSheet)
    XCTAssertFalse(viewModel.showDeleteConfirmation)
    XCTAssertNil(viewModel.metricToDelete)
    XCTAssertNil(viewModel.selectedMetricType)
    XCTAssertNil(viewModel.successMessage)
    XCTAssertFalse(viewModel.showSuccessToast)
    XCTAssertFalse(viewModel.isSubmitting)
  }

  // MARK: - loadMetrics Tests

  func testLoadMetrics_Success() async {
    // Given
    mockService.mockMetrics = [
      mockService.createTestMetric(id: "1", metricType: .velocity, value: 90.0),
      mockService.createTestMetric(id: "2", metricType: .exitVelo, value: 105.0)
    ]

    // When
    await viewModel.loadMetrics()

    // Then
    XCTAssertEqual(viewModel.metrics.count, 2)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(mockService.fetchMetricsCallCount, 1)
  }

  func testLoadMetrics_ServiceError_ShowsError() async {
    // Given
    mockService.shouldSucceed = false

    // When
    await viewModel.loadMetrics()

    // Then
    XCTAssertTrue(viewModel.metrics.isEmpty)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("Failed to load") ?? false)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadMetrics_NoUser_ShowsError() async {
    // Given
    mockAuthManager.user = nil

    // When
    await viewModel.loadMetrics()

    // Then
    XCTAssertTrue(viewModel.metrics.isEmpty)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("sign in") ?? false)
    XCTAssertEqual(mockService.fetchMetricsCallCount, 0)
  }

  func testLoadMetrics_ClearsErrorOnRetry() async {
    // Given - first call fails
    mockService.shouldSucceed = false
    await viewModel.loadMetrics()
    XCTAssertNotNil(viewModel.errorMessage)

    // When - second call succeeds
    mockService.shouldSucceed = true
    mockService.mockMetrics = [mockService.createTestMetric(id: "1")]
    await viewModel.loadMetrics()

    // Then
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.metrics.count, 1)
  }

  func testLoadMetrics_EmptyResult() async {
    // Given
    mockService.mockMetrics = []

    // When
    await viewModel.loadMetrics()

    // Then
    XCTAssertTrue(viewModel.metrics.isEmpty)
    XCTAssertNil(viewModel.errorMessage)
  }

  // MARK: - sortedMetrics Tests

  func testSortedMetrics_OrderedByDateDescending() {
    // Given
    let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let todayDate = Date()

    viewModel.metrics = [
      mockService.createTestMetric(id: "old", recordedDate: oldDate),
      mockService.createTestMetric(id: "today", recordedDate: todayDate),
      mockService.createTestMetric(id: "recent", recordedDate: recentDate)
    ]

    // When
    let sorted = viewModel.sortedMetrics

    // Then
    XCTAssertEqual(sorted[0].id, "today")
    XCTAssertEqual(sorted[1].id, "recent")
    XCTAssertEqual(sorted[2].id, "old")
  }

  // MARK: - availableMetricTypes Tests

  func testAvailableMetricTypes_ReturnsTypesInData() {
    // Given
    viewModel.metrics = [
      mockService.createTestMetric(id: "1", metricType: .velocity),
      mockService.createTestMetric(id: "2", metricType: .exitVelo),
      mockService.createTestMetric(id: "3", metricType: .velocity)
    ]

    // When
    let types = viewModel.availableMetricTypes

    // Then
    XCTAssertEqual(types.count, 2)
    XCTAssertTrue(types.contains(.velocity))
    XCTAssertTrue(types.contains(.exitVelo))
  }

  func testAvailableMetricTypes_EmptyWhenNoMetrics() {
    XCTAssertTrue(viewModel.availableMetricTypes.isEmpty)
  }

  // MARK: - activeMetricType Tests

  func testActiveMetricType_UsesSelectedWhenSet() {
    // Given
    viewModel.metrics = [mockService.createTestMetric(id: "1", metricType: .velocity)]
    viewModel.selectedMetricType = .exitVelo

    // Then
    XCTAssertEqual(viewModel.activeMetricType, .exitVelo)
  }

  func testActiveMetricType_FallsBackToFirstAvailable() {
    // Given
    viewModel.metrics = [mockService.createTestMetric(id: "1", metricType: .velocity)]
    viewModel.selectedMetricType = nil

    // Then
    XCTAssertEqual(viewModel.activeMetricType, .velocity)
  }

  func testActiveMetricType_NilWhenNoMetrics() {
    XCTAssertNil(viewModel.activeMetricType)
  }

  // MARK: - chartMetrics Tests

  func testChartMetrics_FiltersAndSortsByDate() {
    // Given
    let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

    viewModel.metrics = [
      mockService.createTestMetric(id: "v1", metricType: .velocity, recordedDate: recentDate),
      mockService.createTestMetric(id: "e1", metricType: .exitVelo, recordedDate: oldDate),
      mockService.createTestMetric(id: "v2", metricType: .velocity, recordedDate: oldDate)
    ]
    viewModel.selectedMetricType = .velocity

    // When
    let chart = viewModel.chartMetrics

    // Then
    XCTAssertEqual(chart.count, 2)
    XCTAssertEqual(chart[0].id, "v2") // older first (ascending)
    XCTAssertEqual(chart[1].id, "v1")
  }

  func testChartMetrics_EmptyWhenNoActiveType() {
    XCTAssertTrue(viewModel.chartMetrics.isEmpty)
  }

  // MARK: - hasEnoughDataForChart Tests

  func testHasEnoughDataForChart_TrueWithTwoOrMore() {
    // Given
    viewModel.metrics = [
      mockService.createTestMetric(id: "1", metricType: .velocity),
      mockService.createTestMetric(id: "2", metricType: .velocity)
    ]

    // Then
    XCTAssertTrue(viewModel.hasEnoughDataForChart)
  }

  func testHasEnoughDataForChart_FalseWithOne() {
    // Given
    viewModel.metrics = [mockService.createTestMetric(id: "1", metricType: .velocity)]

    // Then
    XCTAssertFalse(viewModel.hasEnoughDataForChart)
  }

  func testHasEnoughDataForChart_FalseWithNone() {
    XCTAssertFalse(viewModel.hasEnoughDataForChart)
  }

  // MARK: - latestMetricsByType Tests

  func testLatestMetricsByType_ReturnsLatestForEachType() {
    // Given
    let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    let recentDate = Date()

    viewModel.metrics = [
      mockService.createTestMetric(id: "v-old", metricType: .velocity, value: 88.0, recordedDate: oldDate),
      mockService.createTestMetric(id: "v-new", metricType: .velocity, value: 92.0, recordedDate: recentDate),
      mockService.createTestMetric(id: "e-1", metricType: .exitVelo, value: 105.0, recordedDate: recentDate)
    ]

    // When
    let latest = viewModel.latestMetricsByType

    // Then
    XCTAssertEqual(latest.count, 2)
    XCTAssertEqual(latest[.velocity]?.id, "v-new")
    XCTAssertEqual(latest[.exitVelo]?.id, "e-1")
  }

  // MARK: - addMetric Tests

  func testAddMetric_Success() async {
    // Given
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = "92.5"
    viewModel.addFormState.unit = "mph"
    viewModel.showAddForm = true

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertEqual(viewModel.metrics.count, 1)
    XCTAssertEqual(mockService.createMetricCallCount, 1)
    XCTAssertFalse(viewModel.showAddForm)
    XCTAssertNotNil(viewModel.successMessage)
    XCTAssertTrue(viewModel.showSuccessToast)
    XCTAssertFalse(viewModel.isSubmitting)
  }

  func testAddMetric_InvalidForm_DoesNothing() async {
    // Given - empty value makes form invalid
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = ""

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertTrue(viewModel.metrics.isEmpty)
    XCTAssertEqual(mockService.createMetricCallCount, 0)
  }

  func testAddMetric_NoUser_DoesNothing() async {
    // Given
    mockAuthManager.user = nil
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = "90.0"

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertTrue(viewModel.metrics.isEmpty)
    XCTAssertEqual(mockService.createMetricCallCount, 0)
  }

  func testAddMetric_ServiceError_ShowsError() async {
    // Given
    mockService.shouldSucceed = false
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = "90.0"

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertTrue(viewModel.metrics.isEmpty)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("Failed to log") ?? false)
    XCTAssertFalse(viewModel.isSubmitting)
  }

  func testAddMetric_UsesDefaultUnit_WhenEmpty() async {
    // Given
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = "90.0"
    viewModel.addFormState.unit = ""

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertEqual(mockService.lastCreateRequest?.unit, "mph")
  }

  func testAddMetric_UsesCustomUnit_WhenProvided() async {
    // Given
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = "90.0"
    viewModel.addFormState.unit = "kph"

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertEqual(mockService.lastCreateRequest?.unit, "kph")
  }

  func testAddMetric_EmptyNotes_SendsNil() async {
    // Given
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = "90.0"
    viewModel.addFormState.notes = ""

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertNil(mockService.lastCreateRequest?.notes)
  }

  func testAddMetric_WithNotes_SendsNotes() async {
    // Given
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = "90.0"
    viewModel.addFormState.notes = "Bullpen session"

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertEqual(mockService.lastCreateRequest?.notes, "Bullpen session")
  }

  func testAddMetric_ResetsFormAfterSuccess() async {
    // Given
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = "90.0"
    viewModel.addFormState.notes = "Test"
    viewModel.addFormState.verified = true

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertNil(viewModel.addFormState.metricType)
    XCTAssertEqual(viewModel.addFormState.value, "")
    XCTAssertEqual(viewModel.addFormState.notes, "")
    XCTAssertFalse(viewModel.addFormState.verified)
  }

  func testAddMetric_NoMetricType_DoesNothing() async {
    // Given
    viewModel.addFormState.metricType = nil
    viewModel.addFormState.value = "90.0"

    // When
    await viewModel.addMetric()

    // Then
    XCTAssertEqual(mockService.createMetricCallCount, 0)
  }

  // MARK: - startEditing Tests

  func testStartEditing_PopulatesEditForm() {
    // Given
    let metric = mockService.createTestMetric(
      id: "metric-1",
      metricType: .exitVelo,
      value: 105.0,
      unit: "mph",
      verified: true,
      notes: "BP drill"
    )

    // When
    viewModel.startEditing(metric)

    // Then
    XCTAssertEqual(viewModel.editingMetric?.id, "metric-1")
    XCTAssertEqual(viewModel.editFormState.metricType, .exitVelo)
    XCTAssertEqual(viewModel.editFormState.value, "105.00")
    XCTAssertEqual(viewModel.editFormState.unit, "mph")
    XCTAssertTrue(viewModel.editFormState.verified)
    XCTAssertEqual(viewModel.editFormState.notes, "BP drill")
    XCTAssertTrue(viewModel.showEditSheet)
  }

  // MARK: - updateMetric Tests

  func testUpdateMetric_Success() async {
    // Given
    let metric = mockService.createTestMetric(id: "metric-1", value: 90.0)
    viewModel.metrics = [metric]
    viewModel.editingMetric = metric
    viewModel.editFormState.metricType = .velocity
    viewModel.editFormState.value = "95.0"
    viewModel.showEditSheet = true

    let updatedMetric = mockService.createTestMetric(id: "metric-1", value: 95.0)
    mockService.mockUpdatedMetric = updatedMetric

    // When
    await viewModel.updateMetric()

    // Then
    XCTAssertEqual(mockService.updateMetricCallCount, 1)
    XCTAssertEqual(viewModel.metrics.first?.value, 95.0)
    XCTAssertFalse(viewModel.showEditSheet)
    XCTAssertNil(viewModel.editingMetric)
    XCTAssertNotNil(viewModel.successMessage)
    XCTAssertTrue(viewModel.showSuccessToast)
    XCTAssertFalse(viewModel.isSubmitting)
  }

  func testUpdateMetric_NoEditingMetric_DoesNothing() async {
    // Given
    viewModel.editingMetric = nil

    // When
    await viewModel.updateMetric()

    // Then
    XCTAssertEqual(mockService.updateMetricCallCount, 0)
  }

  func testUpdateMetric_InvalidForm_DoesNothing() async {
    // Given
    viewModel.editingMetric = mockService.createTestMetric(id: "metric-1")
    viewModel.editFormState.metricType = .velocity
    viewModel.editFormState.value = "invalid"

    // When
    await viewModel.updateMetric()

    // Then
    XCTAssertEqual(mockService.updateMetricCallCount, 0)
  }

  func testUpdateMetric_ServiceError_ShowsError() async {
    // Given
    let metric = mockService.createTestMetric(id: "metric-1")
    viewModel.metrics = [metric]
    viewModel.editingMetric = metric
    viewModel.editFormState.metricType = .velocity
    viewModel.editFormState.value = "95.0"
    mockService.shouldSucceed = false

    // When
    await viewModel.updateMetric()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("Failed to update") ?? false)
    XCTAssertFalse(viewModel.isSubmitting)
  }

  // MARK: - confirmDelete Tests

  func testConfirmDelete_SetsMetricAndShowsConfirmation() {
    // Given
    let metric = mockService.createTestMetric(id: "metric-1")

    // When
    viewModel.confirmDelete(metric)

    // Then
    XCTAssertEqual(viewModel.metricToDelete?.id, "metric-1")
    XCTAssertTrue(viewModel.showDeleteConfirmation)
  }

  // MARK: - deleteMetric Tests

  func testDeleteMetric_Success() async {
    // Given
    let metric = mockService.createTestMetric(id: "metric-1")
    viewModel.metrics = [metric]
    viewModel.metricToDelete = metric
    viewModel.showDeleteConfirmation = true

    // When
    await viewModel.deleteMetric()

    // Then
    XCTAssertTrue(viewModel.metrics.isEmpty)
    XCTAssertEqual(mockService.deleteMetricCallCount, 1)
    XCTAssertNil(viewModel.metricToDelete)
    XCTAssertFalse(viewModel.showDeleteConfirmation)
    XCTAssertNotNil(viewModel.successMessage)
    XCTAssertTrue(viewModel.showSuccessToast)
  }

  func testDeleteMetric_NoMetricToDelete_DoesNothing() async {
    // Given
    viewModel.metricToDelete = nil

    // When
    await viewModel.deleteMetric()

    // Then
    XCTAssertEqual(mockService.deleteMetricCallCount, 0)
  }

  func testDeleteMetric_ServiceError_ShowsError() async {
    // Given
    let metric = mockService.createTestMetric(id: "metric-1")
    viewModel.metrics = [metric]
    viewModel.metricToDelete = metric
    mockService.shouldSucceed = false

    // When
    await viewModel.deleteMetric()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("Failed to delete") ?? false)
    // Metric should still be in the list
    XCTAssertEqual(viewModel.metrics.count, 1)
  }

  // MARK: - calculateTrend Tests

  func testCalculateTrend_Improving_HigherIsBetter() {
    // Given - values going up for velocity (higher is better)
    let values = [85.0, 86.0, 87.0, 90.0, 91.0, 92.0]

    // When
    let trend = viewModel.calculateTrend(values: values, type: .velocity)

    // Then - last 3 avg (91) > first 3 avg (86) * 1.01
    XCTAssertEqual(trend, .improving)
  }

  func testCalculateTrend_Declining_HigherIsBetter() {
    // Given - values going down for velocity
    let values = [92.0, 91.0, 90.0, 85.0, 84.0, 83.0]

    // When
    let trend = viewModel.calculateTrend(values: values, type: .velocity)

    // Then - last 3 avg (84) < first 3 avg (91) * 0.99
    XCTAssertEqual(trend, .declining)
  }

  func testCalculateTrend_Improving_LowerIsBetter() {
    // Given - values going down for ERA (lower is better)
    let values = [4.50, 4.20, 3.80, 3.50, 3.20, 3.00]

    // When
    let trend = viewModel.calculateTrend(values: values, type: .era)

    // Then - last 3 avg (3.23) < first 3 avg (4.17) * 0.99
    XCTAssertEqual(trend, .improving)
  }

  func testCalculateTrend_Declining_LowerIsBetter() {
    // Given - values going up for 60-yard dash (lower is better)
    let values = [6.5, 6.6, 6.7, 7.0, 7.2, 7.5]

    // When
    let trend = viewModel.calculateTrend(values: values, type: .sixtyTime)

    // Then - last 3 avg (7.23) > first 3 avg (6.6) * 1.01
    XCTAssertEqual(trend, .declining)
  }

  func testCalculateTrend_Stable_WhenValuesClose() {
    // Given - values within 1% range
    let values = [90.0, 90.1, 90.0, 90.0, 89.9, 90.1]

    // When
    let trend = viewModel.calculateTrend(values: values, type: .velocity)

    // Then
    XCTAssertEqual(trend, .stable)
  }

  func testCalculateTrend_Stable_WhenOnlyTwoValues() {
    // Given - exactly 2 values (uses first 2 vs last 2 which overlap)
    let values = [90.0, 90.0]

    // When
    let trend = viewModel.calculateTrend(values: values, type: .velocity)

    // Then
    XCTAssertEqual(trend, .stable)
  }

  func testCalculateTrend_Stable_WhenLessThanTwo() {
    // Given
    let values = [90.0]

    // When
    let trend = viewModel.calculateTrend(values: values, type: .velocity)

    // Then
    XCTAssertEqual(trend, .stable)
  }

  func testCalculateTrend_Stable_WhenEmpty() {
    let trend = viewModel.calculateTrend(values: [], type: .velocity)
    XCTAssertEqual(trend, .stable)
  }

  func testCalculateTrend_Stable_WhenFirstAvgIsZero() {
    // Given - first average is 0 (guard returns stable)
    let values = [0.0, 0.0, 0.0, 10.0, 10.0, 10.0]

    // When
    let trend = viewModel.calculateTrend(values: values, type: .velocity)

    // Then
    XCTAssertEqual(trend, .stable)
  }

  // MARK: - metricTrends Tests

  func testMetricTrends_CalculatesForTypesWithTwoOrMore() {
    // Given
    let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    let recentDate = Date()

    viewModel.metrics = [
      mockService.createTestMetric(id: "v1", metricType: .velocity, value: 88.0, recordedDate: oldDate),
      mockService.createTestMetric(id: "v2", metricType: .velocity, value: 92.0, recordedDate: recentDate),
      mockService.createTestMetric(id: "e1", metricType: .exitVelo, value: 105.0, recordedDate: recentDate)
    ]

    // When
    let trends = viewModel.metricTrends

    // Then - only velocity has 2+ records
    XCTAssertEqual(trends.count, 1)
    XCTAssertEqual(trends.first?.type, .velocity)
    XCTAssertEqual(trends.first?.count, 2)
  }

  func testMetricTrends_EmptyWhenNoMetrics() {
    XCTAssertTrue(viewModel.metricTrends.isEmpty)
  }

  func testMetricTrends_EmptyWhenAllSingleEntries() {
    // Given - each type has only 1 entry
    viewModel.metrics = [
      mockService.createTestMetric(id: "1", metricType: .velocity),
      mockService.createTestMetric(id: "2", metricType: .exitVelo),
      mockService.createTestMetric(id: "3", metricType: .era)
    ]

    // When
    let trends = viewModel.metricTrends

    // Then
    XCTAssertTrue(trends.isEmpty)
  }

  func testMetricTrends_CalculatesMinMaxAvg() {
    // Given
    let date1 = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
    let date2 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
    let date3 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

    viewModel.metrics = [
      mockService.createTestMetric(id: "1", metricType: .velocity, value: 88.0, recordedDate: date1),
      mockService.createTestMetric(id: "2", metricType: .velocity, value: 90.0, recordedDate: date2),
      mockService.createTestMetric(id: "3", metricType: .velocity, value: 92.0, recordedDate: date3)
    ]

    // When
    let trends = viewModel.metricTrends
    let velocityTrend = trends.first { $0.type == .velocity }

    // Then
    XCTAssertNotNil(velocityTrend)
    XCTAssertEqual(velocityTrend?.min, 88.0)
    XCTAssertEqual(velocityTrend?.max, 92.0)
    XCTAssertEqual(velocityTrend?.average, 90.0)
    XCTAssertEqual(velocityTrend?.count, 3)
  }

  func testMetricTrends_LimitedToLast10Values() {
    // Given - create 12 metrics for one type
    var metrics: [PerformanceMetric] = []
    for i in 0..<12 {
      let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
      metrics.append(mockService.createTestMetric(
        id: "v\(i)",
        metricType: .velocity,
        value: 85.0 + Double(i),
        recordedDate: date
      ))
    }
    viewModel.metrics = metrics

    // When
    let trends = viewModel.metricTrends
    let velocityTrend = trends.first { $0.type == .velocity }

    // Then - only last 10 values used
    XCTAssertEqual(velocityTrend?.count, 10)
  }

  func testMetricTrends_SortedByDisplayName() {
    // Given
    let date1 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
    let date2 = Date()

    viewModel.metrics = [
      mockService.createTestMetric(id: "v1", metricType: .velocity, value: 88.0, recordedDate: date1),
      mockService.createTestMetric(id: "v2", metricType: .velocity, value: 92.0, recordedDate: date2),
      mockService.createTestMetric(id: "e1", metricType: .exitVelo, value: 100.0, recordedDate: date1),
      mockService.createTestMetric(id: "e2", metricType: .exitVelo, value: 105.0, recordedDate: date2)
    ]

    // When
    let trends = viewModel.metricTrends

    // Then - sorted alphabetically: "Exit Velocity" < "Fastball Velocity"
    XCTAssertEqual(trends.count, 2)
    XCTAssertEqual(trends[0].type, .exitVelo)
    XCTAssertEqual(trends[1].type, .velocity)
  }

  // MARK: - generateCSV Tests

  func testGenerateCSV_IncludesHeader() {
    // When
    let csv = viewModel.generateCSV()

    // Then
    XCTAssertTrue(csv.hasPrefix("Metric Type,Value,Unit,Date,Verified,Notes\n"))
  }

  func testGenerateCSV_IncludesAllMetrics() {
    // Given
    let date = Date()
    viewModel.metrics = [
      mockService.createTestMetric(id: "1", metricType: .velocity, value: 90.0, unit: "mph", recordedDate: date, verified: true, notes: "Bullpen"),
      mockService.createTestMetric(id: "2", metricType: .exitVelo, value: 105.0, unit: "mph", recordedDate: date, verified: false)
    ]

    // When
    let csv = viewModel.generateCSV()
    let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

    // Then
    XCTAssertEqual(lines.count, 3) // header + 2 data rows
    XCTAssertTrue(csv.contains("Fastball Velocity"))
    XCTAssertTrue(csv.contains("Exit Velocity"))
    XCTAssertTrue(csv.contains("90.0"))
    XCTAssertTrue(csv.contains("105.0"))
  }

  func testGenerateCSV_EscapesCommasInNotes() {
    // Given
    viewModel.metrics = [
      mockService.createTestMetric(id: "1", notes: "Great session, best ever")
    ]

    // When
    let csv = viewModel.generateCSV()

    // Then - commas in notes replaced with semicolons
    XCTAssertTrue(csv.contains("Great session; best ever"))
    XCTAssertFalse(csv.contains("Great session, best ever"))
  }

  func testGenerateCSV_HandlesNilNotes() {
    // Given
    viewModel.metrics = [
      mockService.createTestMetric(id: "1", notes: nil)
    ]

    // When
    let csv = viewModel.generateCSV()
    let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

    // Then
    XCTAssertEqual(lines.count, 2)
  }

  func testGenerateCSV_EmptyWhenNoMetrics() {
    let csv = viewModel.generateCSV()
    XCTAssertEqual(csv, "Metric Type,Value,Unit,Date,Verified,Notes\n")
  }

  // MARK: - generatePDF Tests

  @MainActor
  func testGeneratePDF_ReturnsValidPDFData() async {
    // Given
    let mockService = MockPerformanceService()
    let mockAuth = MockAuthManager()
    mockAuth.user = User(
      id: "user1",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "",
      updatedAt: "",
      role: nil
    )

    let viewModel = PerformanceDashboardViewModel(
      performanceService: mockService,
      authManager: mockAuth
    )

    mockService.mockMetrics = [
      PerformanceMetric(
        id: "1",
        userId: "user1",
        metricType: .velocity,
        value: 85.5,
        unit: "mph",
        recordedDate: Date(),
        eventId: nil,
        verified: false,
        notes: nil,
        createdAt: Date(),
        updatedAt: Date()
      )
    ]

    await viewModel.loadMetrics()

    // When
    let pdfData = viewModel.generatePDF()

    // Then
    XCTAssertGreaterThan(pdfData.count, 0)
  }

  // MARK: - Helper Methods

  private func createUser(id: String) -> User {
    User(
      id: id,
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "",
      updatedAt: "",
      role: nil
    )
  }
}
