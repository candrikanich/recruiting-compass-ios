import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "PerformanceService"
)

final class PerformanceServiceImpl: PerformanceManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchMetrics(userId: String) async throws -> [PerformanceMetric] {
    logger.debug("Fetching performance metrics for user \(userId)")
    do {
      let metrics: [PerformanceMetric] = try await supabaseManager.client
        .from("performance_metrics")
        .select()
        .eq("user_id", value: userId)
        .order("recorded_date", ascending: false)
        .execute()
        .value
      logger.info("Fetched \(metrics.count) performance metrics")
      return metrics
    } catch {
      logger.error("Failed to fetch metrics: \(error.localizedDescription)")
      throw error
    }
  }

  func createMetric(userId: String, request: MetricCreateRequest) async throws -> PerformanceMetric {
    logger.debug("Creating metric: \(request.metricType)")

    struct CreatePayload: Codable {
      let userId: String
      let metricType: String
      let value: Double
      let unit: String
      let recordedDate: String
      let verified: Bool
      let notes: String?

      enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case metricType = "metric_type"
        case value
        case unit
        case recordedDate = "recorded_date"
        case verified
        case notes
      }
    }

    let payload = CreatePayload(
      userId: userId,
      metricType: request.metricType,
      value: request.value,
      unit: request.unit,
      recordedDate: request.recordedDate,
      verified: request.verified,
      notes: request.notes
    )

    let result: PerformanceMetric = try await supabaseManager.client
      .from("performance_metrics")
      .insert(payload)
      .select()
      .single()
      .execute()
      .value

    logger.info("Metric created: \(result.id)")
    return result
  }

  func updateMetric(id: String, request: MetricUpdateRequest) async throws -> PerformanceMetric {
    logger.debug("Updating metric: \(id)")

    let result: PerformanceMetric = try await supabaseManager.client
      .from("performance_metrics")
      .update(request)
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Metric updated: \(id)")
    return result
  }

  func deleteMetric(id: String) async throws {
    logger.debug("Deleting metric: \(id)")
    try await supabaseManager.client
      .from("performance_metrics")
      .delete()
      .eq("id", value: id)
      .execute()
    logger.info("Metric deleted: \(id)")
  }
}
