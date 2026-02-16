import Foundation
@testable import TheRecruitingCompass

final class MockAnalyticsService: AnalyticsManaging, @unchecked Sendable {
  // Call counters
  var fetchSummaryCallCount = 0
  var fetchInteractionAnalyticsCallCount = 0
  var fetchPipelineCallCount = 0
  var fetchSchoolAnalyticsCallCount = 0
  var fetchPerformanceCorrelationCallCount = 0

  // Captured parameters
  var lastStartDate: String?
  var lastEndDate: String?

  // Stubbed responses
  var stubbedSummary = AnalyticsSummary.empty
  var stubbedInteractionData = InteractionAnalyticsResponse.InteractionAnalyticsData(
    byType: [],
    bySentiment: []
  )
  var stubbedPipeline: [ChartDataItem] = []
  var stubbedSchoolAnalytics: [ChartDataItem] = []
  var stubbedPerformanceCorrelation: [PerformanceCorrelationResponse.CorrelationDataSet] = []

  // Error control
  var shouldThrowError = false
  var errorToThrow: Error = NSError(domain: "MockAnalyticsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])

  // Per-method error control
  var shouldThrowSummaryError = false
  var shouldThrowInteractionError = false
  var shouldThrowPipelineError = false
  var shouldThrowSchoolError = false
  var shouldThrowPerformanceError = false

  func fetchSummary(startDate: String, endDate: String) async throws -> AnalyticsSummary {
    fetchSummaryCallCount += 1
    lastStartDate = startDate
    lastEndDate = endDate
    if shouldThrowError || shouldThrowSummaryError {
      throw errorToThrow
    }
    return stubbedSummary
  }

  func fetchInteractionAnalytics(startDate: String, endDate: String) async throws -> InteractionAnalyticsResponse.InteractionAnalyticsData {
    fetchInteractionAnalyticsCallCount += 1
    lastStartDate = startDate
    lastEndDate = endDate
    if shouldThrowError || shouldThrowInteractionError {
      throw errorToThrow
    }
    return stubbedInteractionData
  }

  func fetchPipeline() async throws -> [ChartDataItem] {
    fetchPipelineCallCount += 1
    if shouldThrowError || shouldThrowPipelineError {
      throw errorToThrow
    }
    return stubbedPipeline
  }

  func fetchSchoolAnalytics() async throws -> [ChartDataItem] {
    fetchSchoolAnalyticsCallCount += 1
    if shouldThrowError || shouldThrowSchoolError {
      throw errorToThrow
    }
    return stubbedSchoolAnalytics
  }

  func fetchPerformanceCorrelation() async throws -> [PerformanceCorrelationResponse.CorrelationDataSet] {
    fetchPerformanceCorrelationCallCount += 1
    if shouldThrowError || shouldThrowPerformanceError {
      throw errorToThrow
    }
    return stubbedPerformanceCorrelation
  }

  func reset() {
    fetchSummaryCallCount = 0
    fetchInteractionAnalyticsCallCount = 0
    fetchPipelineCallCount = 0
    fetchSchoolAnalyticsCallCount = 0
    fetchPerformanceCorrelationCallCount = 0
    lastStartDate = nil
    lastEndDate = nil
    stubbedSummary = AnalyticsSummary.empty
    stubbedInteractionData = InteractionAnalyticsResponse.InteractionAnalyticsData(byType: [], bySentiment: [])
    stubbedPipeline = []
    stubbedSchoolAnalytics = []
    stubbedPerformanceCorrelation = []
    shouldThrowError = false
    shouldThrowSummaryError = false
    shouldThrowInteractionError = false
    shouldThrowPipelineError = false
    shouldThrowSchoolError = false
    shouldThrowPerformanceError = false
  }
}
