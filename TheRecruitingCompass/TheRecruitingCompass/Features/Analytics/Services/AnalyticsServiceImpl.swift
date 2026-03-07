import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AnalyticsService"
)

// MARK: - Lightweight row types for analytics queries

private struct SchoolRow: Codable, Sendable {
  let status: String
}

private struct InteractionRow: Codable, Sendable {
  let type: String
  let sentiment: String?
}

private struct OfferRow: Codable, Sendable {
  let id: String
}

// MARK: - Service

final class AnalyticsServiceImpl: AnalyticsManaging, Sendable {
  private let supabaseManager: SupabaseManager
  private let userId: String
  private let familyUnitId: String

  init(supabaseManager: SupabaseManager, userId: String, familyUnitId: String) {
    self.supabaseManager = supabaseManager
    self.userId = userId
    self.familyUnitId = familyUnitId
  }

  func fetchSummary(startDate: String, endDate: String) async throws -> AnalyticsSummary {
    logger.debug("Fetching analytics summary for \(startDate) to \(endDate)")

    async let schoolsFetch: [SchoolRow] = supabaseManager.client
      .from("schools")
      .select("status")
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value

    async let interactionsFetch: [InteractionRow] = supabaseManager.client
      .from("interactions")
      .select("type,sentiment")
      .eq("family_unit_id", value: familyUnitId)
      .gte("created_at", value: startDate)
      .lte("created_at", value: endDate)
      .execute()
      .value

    async let offersFetch: [OfferRow] = supabaseManager.client
      .from("offers")
      .select("id")
      .eq("user_id", value: userId)
      .execute()
      .value

    let (schools, interactions, offers) = try await (schoolsFetch, interactionsFetch, offersFetch)
    let commitments = schools.filter { $0.status == SchoolStatus.committed.rawValue }.count

    logger.info("Summary: \(schools.count) schools, \(interactions.count) interactions, \(offers.count) offers")
    return AnalyticsSummary(
      totalSchools: schools.count,
      totalInteractions: interactions.count,
      totalOffers: offers.count,
      commitments: commitments,
      trends: nil
    )
  }

  func fetchInteractionAnalytics(startDate: String, endDate: String) async throws -> InteractionAnalyticsResponse.InteractionAnalyticsData {
    logger.debug("Fetching interaction analytics for \(startDate) to \(endDate)")

    let interactions: [InteractionRow] = try await supabaseManager.client
      .from("interactions")
      .select("type,sentiment")
      .eq("family_unit_id", value: familyUnitId)
      .gte("created_at", value: startDate)
      .lte("created_at", value: endDate)
      .execute()
      .value

    var typeCounts: [String: Int] = [:]
    var sentimentCounts: [String: Int] = [:]
    for row in interactions {
      typeCounts[row.type, default: 0] += 1
      if let s = row.sentiment { sentimentCounts[s, default: 0] += 1 }
    }

    let byType = InteractionType.allCases.compactMap { type -> ChartDataItem? in
      guard let count = typeCounts[type.rawValue], count > 0 else { return nil }
      return ChartDataItem(label: type.displayName, value: count)
    }
    let bySentiment = Sentiment.allCases.compactMap { sentiment -> ChartDataItem? in
      guard let count = sentimentCounts[sentiment.rawValue], count > 0 else { return nil }
      return ChartDataItem(label: sentiment.displayName, value: count)
    }

    logger.info("Interaction analytics: \(byType.count) types, \(bySentiment.count) sentiments")
    return InteractionAnalyticsResponse.InteractionAnalyticsData(byType: byType, bySentiment: bySentiment)
  }

  func fetchPipeline() async throws -> [ChartDataItem] {
    logger.debug("Fetching pipeline data")

    let schools: [SchoolRow] = try await supabaseManager.client
      .from("schools")
      .select("status")
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value

    var statusCounts: [String: Int] = [:]
    for school in schools { statusCounts[school.status, default: 0] += 1 }

    let pipelineOrder: [SchoolStatus] = [
      .interested, .contacted, .campInvite, .recruited,
      .officialVisitInvited, .officialVisitScheduled, .offerReceived, .committed
    ]
    let stages = pipelineOrder.compactMap { status -> ChartDataItem? in
      guard let count = statusCounts[status.rawValue], count > 0 else { return nil }
      return ChartDataItem(label: status.displayName, value: count)
    }

    logger.info("Pipeline: \(stages.count) stages from \(schools.count) schools")
    return stages
  }

  func fetchSchoolAnalytics() async throws -> [ChartDataItem] {
    logger.debug("Fetching school analytics")

    let schools: [SchoolRow] = try await supabaseManager.client
      .from("schools")
      .select("status")
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value

    var statusCounts: [String: Int] = [:]
    for school in schools { statusCounts[school.status, default: 0] += 1 }

    let byStatus = SchoolStatus.allCases.compactMap { status -> ChartDataItem? in
      guard status != .unknown, let count = statusCounts[status.rawValue], count > 0 else { return nil }
      return ChartDataItem(label: status.displayName, value: count)
    }

    logger.info("School analytics: \(byStatus.count) statuses")
    return byStatus
  }

  func fetchPerformanceCorrelation() async throws -> [PerformanceCorrelationResponse.CorrelationDataSet] {
    logger.debug("Fetching performance correlation")

    let metrics: [PerformanceMetric] = try await supabaseManager.client
      .from("performance_metrics")
      .select()
      .eq("user_id", value: userId)
      .order("recorded_date", ascending: false)
      .execute()
      .value

    let exitVeloMetrics = metrics.filter { $0.metricType == .exitVelo }
    let velocityMetrics = metrics.filter { $0.metricType == .velocity }

    guard !exitVeloMetrics.isEmpty, !velocityMetrics.isEmpty else {
      logger.info("Insufficient metric types for correlation (exitVelo: \(exitVeloMetrics.count), velocity: \(velocityMetrics.count))")
      return []
    }

    let points: [PerformanceCorrelationResponse.CorrelationPoint] = exitVeloMetrics.compactMap { exitMetric in
      guard let closest = velocityMetrics.min(by: {
        abs($0.recordedDate.timeIntervalSince(exitMetric.recordedDate)) <
        abs($1.recordedDate.timeIntervalSince(exitMetric.recordedDate))
      }) else { return nil }
      return PerformanceCorrelationResponse.CorrelationPoint(
        x: exitMetric.value,
        y: closest.value,
        label: exitMetric.formattedDate
      )
    }

    logger.info("Performance correlation: \(points.count) data points")
    return [PerformanceCorrelationResponse.CorrelationDataSet(label: "Exit Velo vs Fastball Velo", points: points)]
  }
}
