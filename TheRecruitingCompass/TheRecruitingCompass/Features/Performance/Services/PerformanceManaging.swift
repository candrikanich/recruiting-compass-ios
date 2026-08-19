import Foundation

protocol PerformanceManaging: Sendable {
  func fetchMetrics(userId: String) async throws -> [PerformanceMetric]
  func createMetric(userId: String, request: MetricCreateRequest) async throws -> PerformanceMetric
  func updateMetric(id: String, request: MetricUpdateRequest) async throws -> PerformanceMetric
  /// Promotes one metric to the athlete's headline metric, atomically clearing any prior primary
  /// (DB enforces a single `is_primary` per user). Backed by the `set_primary_metric` RPC.
  func setPrimaryMetric(id: String) async throws
  func deleteMetric(id: String) async throws
}
