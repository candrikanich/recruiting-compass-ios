import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AnalyticsServiceTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Service Initialization

  func testServiceInitializes() {
    let service = AnalyticsServiceImpl(supabaseManager: SupabaseManager.shared, userId: "", familyUnitId: "")
    XCTAssertNotNil(service)
  }

  // MARK: - MockAnalyticsService Contract Tests

  func testMockService_FetchSummary_ReturnsStubbed() async throws {
    let mock = MockAnalyticsService()
    let trend = AnalyticsSummary.TrendData(schools: 5.0, interactions: 12.0, offers: -3.0)
    mock.stubbedSummary = AnalyticsSummary(
      totalSchools: 24,
      totalInteractions: 87,
      totalOffers: 15,
      commitments: 3,
      trends: trend
    )

    let result = try await mock.fetchSummary(startDate: "2026-01-01", endDate: "2026-02-01")

    XCTAssertEqual(result.totalSchools, 24)
    XCTAssertEqual(result.totalInteractions, 87)
    XCTAssertEqual(result.totalOffers, 15)
    XCTAssertEqual(result.commitments, 3)
    XCTAssertEqual(mock.fetchSummaryCallCount, 1)
    XCTAssertEqual(mock.lastStartDate, "2026-01-01")
    XCTAssertEqual(mock.lastEndDate, "2026-02-01")
  }

  func testMockService_FetchSummary_ThrowsOnError() async {
    let mock = MockAnalyticsService()
    mock.shouldThrowError = true

    do {
      _ = try await mock.fetchSummary(startDate: "2026-01-01", endDate: "2026-02-01")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(mock.fetchSummaryCallCount, 1)
    }
  }

  func testMockService_FetchSummary_PerMethodError() async {
    let mock = MockAnalyticsService()
    mock.shouldThrowSummaryError = true

    do {
      _ = try await mock.fetchSummary(startDate: "2026-01-01", endDate: "2026-02-01")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(mock.fetchSummaryCallCount, 1)
    }
  }

  func testMockService_FetchInteractionAnalytics_ReturnsStubbed() async throws {
    let mock = MockAnalyticsService()
    mock.stubbedInteractionData = InteractionAnalyticsResponse.InteractionAnalyticsData(
      byType: [ChartDataItem(label: "Email", value: 34), ChartDataItem(label: "Phone", value: 28)],
      bySentiment: [ChartDataItem(label: "Positive", value: 52)]
    )

    let result = try await mock.fetchInteractionAnalytics(startDate: "2026-01-01", endDate: "2026-02-01")

    XCTAssertEqual(result.byType.count, 2)
    XCTAssertEqual(result.byType[0].label, "Email")
    XCTAssertEqual(result.bySentiment.count, 1)
    XCTAssertEqual(mock.fetchInteractionAnalyticsCallCount, 1)
  }

  func testMockService_FetchInteractionAnalytics_ThrowsOnError() async {
    let mock = MockAnalyticsService()
    mock.shouldThrowInteractionError = true

    do {
      _ = try await mock.fetchInteractionAnalytics(startDate: "2026-01-01", endDate: "2026-02-01")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(mock.fetchInteractionAnalyticsCallCount, 1)
    }
  }

  func testMockService_FetchPipeline_ReturnsStubbed() async throws {
    let mock = MockAnalyticsService()
    mock.stubbedPipeline = [
      ChartDataItem(label: "Initial Contact", value: 250),
      ChartDataItem(label: "Active Discussions", value: 85),
      ChartDataItem(label: "Offers", value: 15),
      ChartDataItem(label: "Committed", value: 3)
    ]

    let result = try await mock.fetchPipeline()

    XCTAssertEqual(result.count, 4)
    XCTAssertEqual(result[0].label, "Initial Contact")
    XCTAssertEqual(result[0].value, 250)
    XCTAssertEqual(mock.fetchPipelineCallCount, 1)
  }

  func testMockService_FetchPipeline_ThrowsOnError() async {
    let mock = MockAnalyticsService()
    mock.shouldThrowPipelineError = true

    do {
      _ = try await mock.fetchPipeline()
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(mock.fetchPipelineCallCount, 1)
    }
  }

  func testMockService_FetchSchoolAnalytics_ReturnsStubbed() async throws {
    let mock = MockAnalyticsService()
    mock.stubbedSchoolAnalytics = [
      ChartDataItem(label: "Active Recruiting", value: 18),
      ChartDataItem(label: "On Wait List", value: 4)
    ]

    let result = try await mock.fetchSchoolAnalytics()

    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0].label, "Active Recruiting")
    XCTAssertEqual(mock.fetchSchoolAnalyticsCallCount, 1)
  }

  func testMockService_FetchSchoolAnalytics_ThrowsOnError() async {
    let mock = MockAnalyticsService()
    mock.shouldThrowSchoolError = true

    do {
      _ = try await mock.fetchSchoolAnalytics()
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(mock.fetchSchoolAnalyticsCallCount, 1)
    }
  }

  func testMockService_FetchPerformanceCorrelation_ReturnsStubbed() async throws {
    let mock = MockAnalyticsService()
    mock.stubbedPerformanceCorrelation = [
      PerformanceCorrelationResponse.CorrelationDataSet(
        label: "Exit Velocity vs Distance",
        points: [
          PerformanceCorrelationResponse.CorrelationPoint(x: 85.0, y: 340.0, label: "Player A"),
          PerformanceCorrelationResponse.CorrelationPoint(x: 90.0, y: 380.0, label: "Player B")
        ]
      )
    ]

    let result = try await mock.fetchPerformanceCorrelation()

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].label, "Exit Velocity vs Distance")
    XCTAssertEqual(result[0].points.count, 2)
    XCTAssertEqual(mock.fetchPerformanceCorrelationCallCount, 1)
  }

  func testMockService_FetchPerformanceCorrelation_ThrowsOnError() async {
    let mock = MockAnalyticsService()
    mock.shouldThrowPerformanceError = true

    do {
      _ = try await mock.fetchPerformanceCorrelation()
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(mock.fetchPerformanceCorrelationCallCount, 1)
    }
  }

  // MARK: - Mock Reset Tests

  func testMockService_Reset_ClearsState() async throws {
    let mock = MockAnalyticsService()
    mock.shouldThrowError = true
    mock.shouldThrowSummaryError = true
    mock.fetchSummaryCallCount = 5
    mock.lastStartDate = "2026-01-01"
    mock.stubbedSummary = AnalyticsSummary(
      totalSchools: 10, totalInteractions: 20, totalOffers: 3, commitments: 1, trends: nil
    )

    mock.reset()

    XCTAssertFalse(mock.shouldThrowError)
    XCTAssertFalse(mock.shouldThrowSummaryError)
    XCTAssertEqual(mock.fetchSummaryCallCount, 0)
    XCTAssertNil(mock.lastStartDate)
    XCTAssertNil(mock.lastEndDate)
    XCTAssertEqual(mock.stubbedSummary, AnalyticsSummary.empty)
    XCTAssertTrue(mock.stubbedPipeline.isEmpty)
    XCTAssertTrue(mock.stubbedSchoolAnalytics.isEmpty)
    XCTAssertTrue(mock.stubbedPerformanceCorrelation.isEmpty)
  }

  // MARK: - Empty Data Tests

  func testMockService_EmptyResponses() async throws {
    let mock = MockAnalyticsService()

    let summary = try await mock.fetchSummary(startDate: "2026-01-01", endDate: "2026-02-01")
    let interactions = try await mock.fetchInteractionAnalytics(startDate: "2026-01-01", endDate: "2026-02-01")
    let pipeline = try await mock.fetchPipeline()
    let schools = try await mock.fetchSchoolAnalytics()
    let performance = try await mock.fetchPerformanceCorrelation()

    XCTAssertEqual(summary, AnalyticsSummary.empty)
    XCTAssertTrue(interactions.byType.isEmpty)
    XCTAssertTrue(interactions.bySentiment.isEmpty)
    XCTAssertTrue(pipeline.isEmpty)
    XCTAssertTrue(schools.isEmpty)
    XCTAssertTrue(performance.isEmpty)
  }

  // MARK: - Global Error vs Per-Method Error

  func testMockService_GlobalError_AffectsAllMethods() async {
    let mock = MockAnalyticsService()
    mock.shouldThrowError = true

    do { _ = try await mock.fetchSummary(startDate: "", endDate: "") } catch {}
    do { _ = try await mock.fetchInteractionAnalytics(startDate: "", endDate: "") } catch {}
    do { _ = try await mock.fetchPipeline() } catch {}
    do { _ = try await mock.fetchSchoolAnalytics() } catch {}
    do { _ = try await mock.fetchPerformanceCorrelation() } catch {}

    XCTAssertEqual(mock.fetchSummaryCallCount, 1)
    XCTAssertEqual(mock.fetchInteractionAnalyticsCallCount, 1)
    XCTAssertEqual(mock.fetchPipelineCallCount, 1)
    XCTAssertEqual(mock.fetchSchoolAnalyticsCallCount, 1)
    XCTAssertEqual(mock.fetchPerformanceCorrelationCallCount, 1)
  }

  func testMockService_DateParameters_CapturedCorrectly() async throws {
    let mock = MockAnalyticsService()

    _ = try await mock.fetchSummary(startDate: "2026-01-15", endDate: "2026-02-15")
    XCTAssertEqual(mock.lastStartDate, "2026-01-15")
    XCTAssertEqual(mock.lastEndDate, "2026-02-15")

    _ = try await mock.fetchInteractionAnalytics(startDate: "2026-02-01", endDate: "2026-02-28")
    XCTAssertEqual(mock.lastStartDate, "2026-02-01")
    XCTAssertEqual(mock.lastEndDate, "2026-02-28")
  }
}
