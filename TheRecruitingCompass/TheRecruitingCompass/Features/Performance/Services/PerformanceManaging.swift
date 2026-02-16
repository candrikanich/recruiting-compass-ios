import Foundation

protocol PerformanceManaging: Sendable {
  func fetchMetrics(userId: String) async throws -> [PerformanceMetric]
  func createMetric(userId: String, request: MetricCreateRequest) async throws -> PerformanceMetric
  func updateMetric(id: String, request: MetricUpdateRequest) async throws -> PerformanceMetric
  func deleteMetric(id: String) async throws
}
