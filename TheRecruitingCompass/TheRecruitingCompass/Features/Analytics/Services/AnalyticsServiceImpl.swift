import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AnalyticsService"
)

final class AnalyticsServiceImpl: AnalyticsManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchSummary(startDate: String, endDate: String) async throws -> AnalyticsSummary {
    logger.debug("Fetching analytics summary for \(startDate) to \(endDate)")
    do {
      let response: AnalyticsSummaryResponse = try await supabaseManager.client
        .functions
        .invoke(
          "analytics-summary",
          options: .init(body: ["startDate": startDate, "endDate": endDate])
        )
      logger.info("Fetched analytics summary successfully")
      return response.data
    } catch {
      logger.error("Failed to fetch analytics summary: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchInteractionAnalytics(startDate: String, endDate: String) async throws -> InteractionAnalyticsResponse.InteractionAnalyticsData {
    logger.debug("Fetching interaction analytics for \(startDate) to \(endDate)")
    do {
      let response: InteractionAnalyticsResponse = try await supabaseManager.client
        .functions
        .invoke(
          "analytics-interactions",
          options: .init(body: ["startDate": startDate, "endDate": endDate])
        )
      logger.info("Fetched interaction analytics successfully")
      return response.data
    } catch {
      logger.error("Failed to fetch interaction analytics: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchPipeline() async throws -> [ChartDataItem] {
    logger.debug("Fetching pipeline data")
    do {
      let response: PipelineResponse = try await supabaseManager.client
        .functions
        .invoke("analytics-pipeline")
      logger.info("Fetched pipeline data: \(response.data.stages.count) stages")
      return response.data.stages
    } catch {
      logger.error("Failed to fetch pipeline data: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchSchoolAnalytics() async throws -> [ChartDataItem] {
    logger.debug("Fetching school analytics")
    do {
      let response: SchoolAnalyticsResponse = try await supabaseManager.client
        .functions
        .invoke("analytics-schools")
      logger.info("Fetched school analytics: \(response.data.byStatus.count) statuses")
      return response.data.byStatus
    } catch {
      logger.error("Failed to fetch school analytics: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchPerformanceCorrelation() async throws -> [PerformanceCorrelationResponse.CorrelationDataSet] {
    logger.debug("Fetching performance correlation")
    do {
      let response: PerformanceCorrelationResponse = try await supabaseManager.client
        .functions
        .invoke("analytics-performance-correlation")
      logger.info("Fetched performance correlation: \(response.data.datasets.count) datasets")
      return response.data.datasets
    } catch {
      logger.error("Failed to fetch performance correlation: \(error.localizedDescription)")
      throw error
    }
  }
}
