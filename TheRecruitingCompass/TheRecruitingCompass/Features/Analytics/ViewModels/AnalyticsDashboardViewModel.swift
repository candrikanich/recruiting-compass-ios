import Foundation
import Observation
import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AnalyticsDashboardViewModel"
)

@Observable
@MainActor
final class AnalyticsDashboardViewModel {
  var summary: AnalyticsSummary = .empty
  var interactionTypesData: [PieChartSegment] = []
  var sentimentData: [PieChartSegment] = []
  var pipelineData: [FunnelStage] = []
  var schoolStatusData: [PieChartSegment] = []
  var performanceData: ScatterDataSet?
  var dateRange: AnalyticsDateRange = .last30Days
  var isLoading = false
  var errorMessage: String?
  var showExportSheet = false
  var showDatePicker = false
  var customStartDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
  var customEndDate = Date()

  private let analyticsService: any AnalyticsManaging

  // MARK: - Computed Properties

  var hasData: Bool {
    summary.totalSchools > 0 || summary.totalInteractions > 0
  }

  var hasInteractionData: Bool {
    !interactionTypesData.isEmpty
  }

  var hasSentimentData: Bool {
    !sentimentData.isEmpty
  }

  var hasPipelineData: Bool {
    !pipelineData.isEmpty
  }

  var hasSchoolData: Bool {
    !schoolStatusData.isEmpty
  }

  var hasPerformanceData: Bool {
    guard let data = performanceData else { return false }
    return !data.points.isEmpty
  }

  var summaryCards: [SummaryCard] {
    [
      SummaryCard(
        title: "Total Schools",
        value: summary.totalSchools,
        iconName: "building.2.fill",
        color: AnalyticsChartColors.primary,
        trend: summary.trends?.schoolsTrendLabel
      ),
      SummaryCard(
        title: "Interactions",
        value: summary.totalInteractions,
        iconName: "bubble.left.and.bubble.right.fill",
        color: AnalyticsChartColors.secondary,
        trend: summary.trends?.interactionsTrendLabel
      ),
      SummaryCard(
        title: "Offers",
        value: summary.totalOffers,
        iconName: "envelope.open.fill",
        color: AnalyticsChartColors.tertiary,
        trend: summary.trends?.offersTrendLabel
      ),
      SummaryCard(
        title: "Commitments",
        value: summary.commitments,
        iconName: "checkmark.seal.fill",
        color: AnalyticsChartColors.quaternary,
        trend: nil
      )
    ]
  }

  // MARK: - Init

  init(analyticsService: (any AnalyticsManaging)? = nil) {
    self.analyticsService = analyticsService ?? AnalyticsServiceImpl(supabaseManager: .shared)
  }

  // MARK: - Actions

  func loadAllData() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.loadSummary() }
      group.addTask { await self.loadInteractionAnalytics() }
      group.addTask { await self.loadPipeline() }
      group.addTask { await self.loadSchoolAnalytics() }
      group.addTask { await self.loadPerformanceCorrelation() }
    }
  }

  func setDateRange(_ range: AnalyticsDateRange) async {
    dateRange = range
    await loadAllData()
  }

  func applyCustomDateRange() async {
    dateRange = .custom(start: customStartDate, end: customEndDate)
    showDatePicker = false
    await loadAllData()
  }

  func retry() async {
    await loadAllData()
  }

  // MARK: - Export

  func generateCSVExport() -> String {
    var csv = "Analytics Dashboard Export\n"
    csv += "Date Range: \(dateRange.displayName)\n\n"

    csv += "Summary Statistics\n"
    csv += "Metric,Value\n"
    csv += "Total Schools,\(summary.totalSchools)\n"
    csv += "Total Interactions,\(summary.totalInteractions)\n"
    csv += "Total Offers,\(summary.totalOffers)\n"
    csv += "Commitments,\(summary.commitments)\n\n"

    csv += csvSection("Interaction Types", columnHeader: "Type", items: interactionTypesData)
    csv += csvSection("Sentiment Breakdown", columnHeader: "Sentiment", items: sentimentData)
    csv += csvSection("Recruiting Pipeline", columnHeader: "Stage", items: pipelineData)
    csv += csvSection("School Status Distribution", columnHeader: "Status", items: schoolStatusData)

    return csv
  }

  private func csvSection<T: ChartLabelValue>(_ title: String, columnHeader: String, items: [T]) -> String {
    guard !items.isEmpty else { return "" }
    var section = "\(title)\n\(columnHeader),Count\n"
    for item in items {
      section += "\(item.label),\(item.value)\n"
    }
    section += "\n"
    return section
  }

  func exportFileURL(format: AnalyticsExportFormat) -> URL? {
    let fileName = "analytics_export.\(format.fileExtension)"
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent(fileName)

    switch format {
    case .csv:
      let csvContent = generateCSVExport()
      do {
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
      } catch {
        logger.error("Failed to write CSV: \(error.localizedDescription)")
        return nil
      }
    case .excel, .pdf:
      logger.info("Export format \(format.displayName) not yet implemented")
      return nil
    }
  }

  // MARK: - Private Loaders

  private func loadSummary() async {
    do {
      summary = try await analyticsService.fetchSummary(
        startDate: dateRange.queryStartDate,
        endDate: dateRange.queryEndDate
      )
    } catch {
      logger.error("Failed to load summary: \(error.localizedDescription)")
      if errorMessage == nil {
        errorMessage = "Failed to load analytics. Pull to refresh."
      }
    }
  }

  private func loadInteractionAnalytics() async {
    do {
      let data = try await analyticsService.fetchInteractionAnalytics(
        startDate: dateRange.queryStartDate,
        endDate: dateRange.queryEndDate
      )
      interactionTypesData = data.byType.enumerated().map { index, item in
        PieChartSegment(
          label: item.label,
          value: item.value,
          color: AnalyticsChartColors.color(at: index)
        )
      }
      sentimentData = data.bySentiment.map { item in
        PieChartSegment(
          label: item.label,
          value: item.value,
          color: AnalyticsChartColors.sentimentColors[item.label] ?? .gray
        )
      }
    } catch {
      logger.error("Failed to load interaction analytics: \(error.localizedDescription)")
    }
  }

  private func loadPipeline() async {
    do {
      let stages = try await analyticsService.fetchPipeline()
      pipelineData = stages.enumerated().map { index, item in
        FunnelStage(
          label: item.label,
          value: item.value,
          color: AnalyticsChartColors.funnelPalette[index % AnalyticsChartColors.funnelPalette.count]
        )
      }
    } catch {
      logger.error("Failed to load pipeline: \(error.localizedDescription)")
    }
  }

  private func loadSchoolAnalytics() async {
    do {
      let statuses = try await analyticsService.fetchSchoolAnalytics()
      schoolStatusData = statuses.enumerated().map { index, item in
        PieChartSegment(
          label: item.label,
          value: item.value,
          color: AnalyticsChartColors.color(at: index)
        )
      }
    } catch {
      logger.error("Failed to load school analytics: \(error.localizedDescription)")
    }
  }

  private func loadPerformanceCorrelation() async {
    do {
      let datasets = try await analyticsService.fetchPerformanceCorrelation()
      if let first = datasets.first {
        let points = first.points.map { point in
          ScatterDataPoint(
            x: point.x,
            y: point.y,
            label: point.label,
            color: AnalyticsChartColors.primary
          )
        }
        performanceData = ScatterDataSet(
          label: first.label,
          points: points,
          xAxisLabel: "Exit Velocity (mph)",
          yAxisLabel: "Distance (ft)"
        )
      }
    } catch {
      logger.error("Failed to load performance correlation: \(error.localizedDescription)")
    }
  }
}
