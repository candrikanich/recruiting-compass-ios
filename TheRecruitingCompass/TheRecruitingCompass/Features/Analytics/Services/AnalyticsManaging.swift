import Foundation

protocol AnalyticsManaging: Sendable {
  func fetchSummary(startDate: String, endDate: String) async throws -> AnalyticsSummary
  func fetchInteractionAnalytics(startDate: String, endDate: String) async throws -> InteractionAnalyticsResponse.InteractionAnalyticsData
  func fetchPipeline() async throws -> [ChartDataItem]
  func fetchSchoolAnalytics() async throws -> [ChartDataItem]
  func fetchPerformanceCorrelation() async throws -> [PerformanceCorrelationResponse.CorrelationDataSet]
}
