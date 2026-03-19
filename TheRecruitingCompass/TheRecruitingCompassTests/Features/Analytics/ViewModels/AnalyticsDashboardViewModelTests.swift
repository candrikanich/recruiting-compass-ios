import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AnalyticsDashboardViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: AnalyticsDashboardViewModel!
  var mockService: MockAnalyticsService!

  override func setUp() async throws {
    mockService = MockAnalyticsService()
    viewModel = AnalyticsDashboardViewModel(analyticsService: mockService)
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
  }

  // MARK: - Initial State Tests

  func testInitialState() {
    XCTAssertEqual(viewModel.summary, AnalyticsSummary.empty)
    XCTAssertTrue(viewModel.interactionTypesData.isEmpty)
    XCTAssertTrue(viewModel.sentimentData.isEmpty)
    XCTAssertTrue(viewModel.pipelineData.isEmpty)
    XCTAssertTrue(viewModel.schoolStatusData.isEmpty)
    XCTAssertNil(viewModel.performanceData)
    XCTAssertEqual(viewModel.dateRange, .last30Days)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.showExportSheet)
    XCTAssertFalse(viewModel.showDatePicker)
  }

  func testInitialState_ComputedProperties() {
    XCTAssertFalse(viewModel.hasData)
    XCTAssertFalse(viewModel.hasInteractionData)
    XCTAssertFalse(viewModel.hasSentimentData)
    XCTAssertFalse(viewModel.hasPipelineData)
    XCTAssertFalse(viewModel.hasSchoolData)
    XCTAssertFalse(viewModel.hasPerformanceData)
  }

  // MARK: - LoadAllData Tests

  func testLoadAllData_Success_PopulatesAllData() async {
    configureMockWithFullData()

    await viewModel.loadAllData()

    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.summary.totalSchools, 24)
    XCTAssertEqual(viewModel.summary.totalInteractions, 87)
    XCTAssertEqual(viewModel.interactionTypesData.count, 2)
    XCTAssertEqual(viewModel.sentimentData.count, 2)
    XCTAssertEqual(viewModel.pipelineData.count, 4)
    XCTAssertEqual(viewModel.schoolStatusData.count, 3)
    XCTAssertNotNil(viewModel.performanceData)
  }

  func testLoadAllData_CallsAllServiceMethods() async {
    configureMockWithFullData()

    await viewModel.loadAllData()

    XCTAssertEqual(mockService.fetchSummaryCallCount, 1)
    XCTAssertEqual(mockService.fetchInteractionAnalyticsCallCount, 1)
    XCTAssertEqual(mockService.fetchPipelineCallCount, 1)
    XCTAssertEqual(mockService.fetchSchoolAnalyticsCallCount, 1)
    XCTAssertEqual(mockService.fetchPerformanceCorrelationCallCount, 1)
  }

  func testLoadAllData_SetsLoadingToFalseWhenDone() async {
    await viewModel.loadAllData()

    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadAllData_SummaryError_SetsErrorMessage() async {
    mockService.shouldThrowSummaryError = true

    await viewModel.loadAllData()

    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.errorMessage, "Failed to load analytics. Pull to refresh.")
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadAllData_InteractionError_DoesNotSetGlobalError() async {
    mockService.shouldThrowInteractionError = true
    mockService.stubbedSummary = makeSummary()

    await viewModel.loadAllData()

    // Summary loads fine, interaction error is silently logged
    XCTAssertEqual(viewModel.summary.totalSchools, 24)
    XCTAssertTrue(viewModel.interactionTypesData.isEmpty)
  }

  func testLoadAllData_EmptyData() async {
    await viewModel.loadAllData()

    XCTAssertEqual(viewModel.summary, AnalyticsSummary.empty)
    XCTAssertTrue(viewModel.interactionTypesData.isEmpty)
    XCTAssertTrue(viewModel.pipelineData.isEmpty)
    XCTAssertFalse(viewModel.hasData)
  }

  // MARK: - hasData Computed Property Tests

  func testHasData_TrueWhenSchoolsPresent() async {
    mockService.stubbedSummary = AnalyticsSummary(
      totalSchools: 5, totalInteractions: 0, totalOffers: 0, commitments: 0, trends: nil
    )

    await viewModel.loadAllData()

    XCTAssertTrue(viewModel.hasData)
  }

  func testHasData_TrueWhenInteractionsPresent() async {
    mockService.stubbedSummary = AnalyticsSummary(
      totalSchools: 0, totalInteractions: 10, totalOffers: 0, commitments: 0, trends: nil
    )

    await viewModel.loadAllData()

    XCTAssertTrue(viewModel.hasData)
  }

  func testHasData_FalseWhenAllZero() async {
    await viewModel.loadAllData()

    XCTAssertFalse(viewModel.hasData)
  }

  // MARK: - hasInteractionData Tests

  func testHasInteractionData_TrueWithData() async {
    mockService.stubbedInteractionData = InteractionAnalyticsResponse.InteractionAnalyticsData(
      byType: [ChartDataItem(label: "Email", value: 34)],
      bySentiment: []
    )

    await viewModel.loadAllData()

    XCTAssertTrue(viewModel.hasInteractionData)
  }

  func testHasInteractionData_FalseWhenEmpty() async {
    await viewModel.loadAllData()

    XCTAssertFalse(viewModel.hasInteractionData)
  }

  // MARK: - hasSentimentData Tests

  func testHasSentimentData_TrueWithData() async {
    mockService.stubbedInteractionData = InteractionAnalyticsResponse.InteractionAnalyticsData(
      byType: [],
      bySentiment: [ChartDataItem(label: "Positive", value: 52)]
    )

    await viewModel.loadAllData()

    XCTAssertTrue(viewModel.hasSentimentData)
  }

  // MARK: - hasPipelineData Tests

  func testHasPipelineData_TrueWithData() async {
    mockService.stubbedPipeline = [ChartDataItem(label: "Contact", value: 100)]

    await viewModel.loadAllData()

    XCTAssertTrue(viewModel.hasPipelineData)
  }

  // MARK: - hasSchoolData Tests

  func testHasSchoolData_TrueWithData() async {
    mockService.stubbedSchoolAnalytics = [ChartDataItem(label: "Active", value: 18)]

    await viewModel.loadAllData()

    XCTAssertTrue(viewModel.hasSchoolData)
  }

  // MARK: - hasPerformanceData Tests

  func testHasPerformanceData_TrueWithData() async {
    mockService.stubbedPerformanceCorrelation = [
      PerformanceCorrelationResponse.CorrelationDataSet(
        label: "Test",
        points: [PerformanceCorrelationResponse.CorrelationPoint(x: 1.0, y: 2.0, label: "P1")]
      )
    ]

    await viewModel.loadAllData()

    XCTAssertTrue(viewModel.hasPerformanceData)
  }

  func testHasPerformanceData_FalseWithEmptyPoints() async {
    mockService.stubbedPerformanceCorrelation = [
      PerformanceCorrelationResponse.CorrelationDataSet(label: "Empty", points: [])
    ]

    await viewModel.loadAllData()

    // Empty points list, so hasPerformanceData should be false
    XCTAssertFalse(viewModel.hasPerformanceData)
  }

  func testHasPerformanceData_FalseWhenNil() async {
    await viewModel.loadAllData()

    XCTAssertFalse(viewModel.hasPerformanceData)
  }

  // MARK: - Data Mapping Tests

  func testInteractionTypes_MappedCorrectly() async {
    mockService.stubbedInteractionData = InteractionAnalyticsResponse.InteractionAnalyticsData(
      byType: [
        ChartDataItem(label: "Email", value: 34),
        ChartDataItem(label: "Phone Call", value: 28)
      ],
      bySentiment: []
    )

    await viewModel.loadAllData()

    XCTAssertEqual(viewModel.interactionTypesData.count, 2)
    XCTAssertEqual(viewModel.interactionTypesData[0].label, "Email")
    XCTAssertEqual(viewModel.interactionTypesData[0].value, 34)
    XCTAssertEqual(viewModel.interactionTypesData[1].label, "Phone Call")
    XCTAssertEqual(viewModel.interactionTypesData[1].value, 28)
  }

  func testSentiment_UsesChartColors() async {
    mockService.stubbedInteractionData = InteractionAnalyticsResponse.InteractionAnalyticsData(
      byType: [],
      bySentiment: [
        ChartDataItem(label: "Positive", value: 52),
        ChartDataItem(label: "Negative", value: 10)
      ]
    )

    await viewModel.loadAllData()

    XCTAssertEqual(viewModel.sentimentData.count, 2)
    XCTAssertEqual(viewModel.sentimentData[0].label, "Positive")
    XCTAssertEqual(viewModel.sentimentData[0].color, AnalyticsChartColors.secondary)
    XCTAssertEqual(viewModel.sentimentData[1].label, "Negative")
    XCTAssertEqual(viewModel.sentimentData[1].color, AnalyticsChartColors.quaternary)
  }

  func testPipeline_MappedCorrectly() async {
    mockService.stubbedPipeline = [
      ChartDataItem(label: "Initial Contact", value: 250),
      ChartDataItem(label: "Active Discussions", value: 85),
      ChartDataItem(label: "Offers", value: 15),
      ChartDataItem(label: "Committed", value: 3)
    ]

    await viewModel.loadAllData()

    XCTAssertEqual(viewModel.pipelineData.count, 4)
    XCTAssertEqual(viewModel.pipelineData[0].label, "Initial Contact")
    XCTAssertEqual(viewModel.pipelineData[0].value, 250)
    XCTAssertEqual(viewModel.pipelineData[3].label, "Committed")
    XCTAssertEqual(viewModel.pipelineData[3].value, 3)
  }

  func testSchoolAnalytics_MappedCorrectly() async {
    mockService.stubbedSchoolAnalytics = [
      ChartDataItem(label: "Active Recruiting", value: 18),
      ChartDataItem(label: "On Wait List", value: 4)
    ]

    await viewModel.loadAllData()

    XCTAssertEqual(viewModel.schoolStatusData.count, 2)
    XCTAssertEqual(viewModel.schoolStatusData[0].label, "Active Recruiting")
    XCTAssertEqual(viewModel.schoolStatusData[0].value, 18)
  }

  func testPerformanceCorrelation_MappedCorrectly() async {
    mockService.stubbedPerformanceCorrelation = [
      PerformanceCorrelationResponse.CorrelationDataSet(
        label: "Exit Velocity vs Distance",
        points: [
          PerformanceCorrelationResponse.CorrelationPoint(x: 85.0, y: 340.0, label: "Player A"),
          PerformanceCorrelationResponse.CorrelationPoint(x: 90.0, y: 380.0, label: "Player B")
        ]
      )
    ]

    await viewModel.loadAllData()

    XCTAssertNotNil(viewModel.performanceData)
    XCTAssertEqual(viewModel.performanceData?.label, "Exit Velocity vs Distance")
    XCTAssertEqual(viewModel.performanceData?.points.count, 2)
    XCTAssertEqual(viewModel.performanceData?.points[0].x, 85.0)
    XCTAssertEqual(viewModel.performanceData?.points[0].y, 340.0)
    XCTAssertEqual(viewModel.performanceData?.points[0].label, "Player A")
    XCTAssertEqual(viewModel.performanceData?.xAxisLabel, "Exit Velocity (mph)")
    XCTAssertEqual(viewModel.performanceData?.yAxisLabel, "Distance (ft)")
  }

  func testPerformanceCorrelation_EmptyDatasets_DoesNotSetData() async {
    mockService.stubbedPerformanceCorrelation = []

    await viewModel.loadAllData()

    XCTAssertNil(viewModel.performanceData)
  }

  // MARK: - setDateRange Tests

  func testSetDateRange_UpdatesDateRange() async {
    await viewModel.setDateRange(.last7Days)

    XCTAssertEqual(viewModel.dateRange, .last7Days)
  }

  func testSetDateRange_ReloadsData() async {
    configureMockWithFullData()

    await viewModel.setDateRange(.last90Days)

    XCTAssertEqual(mockService.fetchSummaryCallCount, 1)
    XCTAssertEqual(viewModel.dateRange, .last90Days)
  }

  func testSetDateRange_Last7Days() async {
    await viewModel.setDateRange(.last7Days)

    XCTAssertEqual(viewModel.dateRange, .last7Days)
    XCTAssertEqual(mockService.fetchSummaryCallCount, 1)
  }

  // MARK: - applyCustomDateRange Tests

  func testApplyCustomDateRange_SetsCustomRange() async {
    let start = Date(timeIntervalSince1970: 1000000)
    let end = Date(timeIntervalSince1970: 2000000)
    viewModel.customStartDate = start
    viewModel.customEndDate = end
    viewModel.showDatePicker = true

    await viewModel.applyCustomDateRange()

    XCTAssertEqual(viewModel.dateRange, .custom(start: start, end: end))
    XCTAssertFalse(viewModel.showDatePicker)
    XCTAssertEqual(mockService.fetchSummaryCallCount, 1)
  }

  // MARK: - retry Tests

  func testRetry_ReloadsData() async {
    configureMockWithFullData()

    await viewModel.retry()

    XCTAssertEqual(mockService.fetchSummaryCallCount, 1)
    XCTAssertEqual(viewModel.summary.totalSchools, 24)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testRetry_ClearsPreviousError() async {
    mockService.shouldThrowSummaryError = true
    await viewModel.loadAllData()
    XCTAssertNotNil(viewModel.errorMessage)

    mockService.shouldThrowSummaryError = false
    mockService.stubbedSummary = makeSummary()
    await viewModel.retry()

    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.summary.totalSchools, 24)
  }

  // MARK: - SummaryCards Tests

  func testSummaryCards_ReturnsFourCards() async {
    mockService.stubbedSummary = makeSummary()
    await viewModel.loadAllData()

    XCTAssertEqual(viewModel.summaryCards.count, 4)
  }

  func testSummaryCards_CorrectTitles() async {
    mockService.stubbedSummary = makeSummary()
    await viewModel.loadAllData()

    let cards = viewModel.summaryCards
    XCTAssertEqual(cards[0].title, "Total Schools")
    XCTAssertEqual(cards[1].title, "Interactions")
    XCTAssertEqual(cards[2].title, "Offers")
    XCTAssertEqual(cards[3].title, "Commitments")
  }

  func testSummaryCards_CorrectValues() async {
    mockService.stubbedSummary = makeSummary()
    await viewModel.loadAllData()

    let cards = viewModel.summaryCards
    XCTAssertEqual(cards[0].value, 24)
    XCTAssertEqual(cards[1].value, 87)
    XCTAssertEqual(cards[2].value, 15)
    XCTAssertEqual(cards[3].value, 3)
  }

  func testSummaryCards_TrendsPopulated() async {
    mockService.stubbedSummary = makeSummary()
    await viewModel.loadAllData()

    let cards = viewModel.summaryCards
    XCTAssertEqual(cards[0].trend, "+5% vs last period")
    XCTAssertEqual(cards[1].trend, "+12% vs last period")
    XCTAssertEqual(cards[2].trend, "-3% vs last period")
    XCTAssertNil(cards[3].trend)
  }

  func testSummaryCards_ColorsAssigned() async {
    mockService.stubbedSummary = makeSummary()
    await viewModel.loadAllData()

    let cards = viewModel.summaryCards
    XCTAssertEqual(cards[0].color, AnalyticsChartColors.primary)
    XCTAssertEqual(cards[1].color, AnalyticsChartColors.secondary)
    XCTAssertEqual(cards[2].color, AnalyticsChartColors.tertiary)
    XCTAssertEqual(cards[3].color, AnalyticsChartColors.quaternary)
  }

  // MARK: - SummaryCard Model Tests

  func testSummaryCard_IsPositiveTrend() {
    let card = SummaryCard(
      title: "Schools", value: 10, iconName: "building.2.fill",
      color: .blue, trend: "+5% vs last period"
    )
    XCTAssertTrue(card.isPositiveTrend)
    XCTAssertFalse(card.isNegativeTrend)
  }

  func testSummaryCard_IsNegativeTrend() {
    let card = SummaryCard(
      title: "Offers", value: 3, iconName: "envelope.open.fill",
      color: .orange, trend: "-3% vs last period"
    )
    XCTAssertFalse(card.isPositiveTrend)
    XCTAssertTrue(card.isNegativeTrend)
  }

  func testSummaryCard_NilTrend() {
    let card = SummaryCard(
      title: "Commitments", value: 1, iconName: "checkmark.seal.fill",
      color: .red, trend: nil
    )
    XCTAssertFalse(card.isPositiveTrend)
    XCTAssertFalse(card.isNegativeTrend)
  }

  func testSummaryCard_ZeroTrend() {
    let card = SummaryCard(
      title: "Test", value: 0, iconName: "star",
      color: .gray, trend: "+0% vs last period"
    )
    XCTAssertTrue(card.isPositiveTrend)
    XCTAssertFalse(card.isNegativeTrend)
  }

  func testSummaryCard_Identifiable_UniqueIds() {
    let card1 = SummaryCard(title: "A", value: 1, iconName: "star", color: .blue, trend: nil)
    let card2 = SummaryCard(title: "A", value: 1, iconName: "star", color: .blue, trend: nil)
    XCTAssertNotEqual(card1.id, card2.id)
  }

  // MARK: - CSV Export Tests

  func testGenerateCSVExport_EmptyData() {
    let csv = viewModel.generateCSVExport()

    XCTAssertTrue(csv.contains("Analytics Dashboard Export"))
    XCTAssertTrue(csv.contains("Date Range: Last 30 Days"))
    XCTAssertTrue(csv.contains("Summary Statistics"))
    XCTAssertTrue(csv.contains("Total Schools,0"))
    XCTAssertTrue(csv.contains("Total Interactions,0"))
    XCTAssertTrue(csv.contains("Total Offers,0"))
    XCTAssertTrue(csv.contains("Commitments,0"))
  }

  func testGenerateCSVExport_WithFullData() async {
    configureMockWithFullData()
    await viewModel.loadAllData()

    let csv = viewModel.generateCSVExport()

    XCTAssertTrue(csv.contains("Total Schools,24"))
    XCTAssertTrue(csv.contains("Total Interactions,87"))
    XCTAssertTrue(csv.contains("Interaction Types"))
    XCTAssertTrue(csv.contains("Email,34"))
    XCTAssertTrue(csv.contains("Sentiment Breakdown"))
    XCTAssertTrue(csv.contains("Positive,52"))
    XCTAssertTrue(csv.contains("Recruiting Pipeline"))
    XCTAssertTrue(csv.contains("Initial Contact,250"))
    XCTAssertTrue(csv.contains("School Status Distribution"))
    XCTAssertTrue(csv.contains("Active Recruiting,18"))
  }

  func testGenerateCSVExport_DateRangeReflected() async {
    await viewModel.setDateRange(.last7Days)

    let csv = viewModel.generateCSVExport()

    XCTAssertTrue(csv.contains("Date Range: Last 7 Days"))
  }

  // MARK: - ExportFileURL Tests

  func testExportFileURL_CSV_ReturnsURL() async {
    configureMockWithFullData()
    await viewModel.loadAllData()

    let url = viewModel.exportFileURL(format: .csv)

    XCTAssertNotNil(url)
    XCTAssertTrue(url?.lastPathComponent.hasSuffix(".csv") ?? false)
  }

  func testExportFileURL_Excel_ReturnsURL() async {
    configureMockWithFullData()
    await viewModel.loadAllData()

    let url = viewModel.exportFileURL(format: .excel)

    XCTAssertNotNil(url)
    XCTAssertTrue(url?.lastPathComponent.hasSuffix(".xlsx") ?? false)
  }

  func testExportFileURL_Excel_ContainsCSVContent() async {
    configureMockWithFullData()
    await viewModel.loadAllData()

    let url = viewModel.exportFileURL(format: .excel)

    XCTAssertNotNil(url)
    if let url = url, let content = try? String(contentsOf: url, encoding: .utf8) {
      XCTAssertTrue(content.contains("Analytics Dashboard Export"))
      XCTAssertTrue(content.contains("Total Schools,24"))
    }
  }

  func testExportFileURL_PDF_ReturnsURL() async {
    configureMockWithFullData()
    await viewModel.loadAllData()

    let url = viewModel.exportFileURL(format: .pdf)

    XCTAssertNotNil(url)
    XCTAssertTrue(url?.lastPathComponent.hasSuffix(".pdf") ?? false)
  }

  func testExportFileURL_PDF_ContainsValidPDFData() async {
    configureMockWithFullData()
    await viewModel.loadAllData()

    let url = viewModel.exportFileURL(format: .pdf)

    XCTAssertNotNil(url)
    if let url = url, let data = try? Data(contentsOf: url) {
      XCTAssertGreaterThan(data.count, 0)
      let pdfHeader = String(data: data.prefix(5), encoding: .ascii)
      XCTAssertEqual(pdfHeader, "%PDF-")
    }
  }

  // MARK: - Error Recovery Tests

  func testMultipleLoads_ClearsPreviousData() async {
    configureMockWithFullData()
    await viewModel.loadAllData()
    XCTAssertEqual(viewModel.summary.totalSchools, 24)

    mockService.stubbedSummary = AnalyticsSummary(
      totalSchools: 50, totalInteractions: 200, totalOffers: 25, commitments: 5, trends: nil
    )

    await viewModel.loadAllData()
    XCTAssertEqual(viewModel.summary.totalSchools, 50)
  }

  // MARK: - Helpers

  private func makeSummary() -> AnalyticsSummary {
    AnalyticsSummary(
      totalSchools: 24,
      totalInteractions: 87,
      totalOffers: 15,
      commitments: 3,
      trends: AnalyticsSummary.TrendData(schools: 5.0, interactions: 12.0, offers: -3.0)
    )
  }

  private func configureMockWithFullData() {
    mockService.stubbedSummary = makeSummary()

    mockService.stubbedInteractionData = InteractionAnalyticsResponse.InteractionAnalyticsData(
      byType: [
        ChartDataItem(label: "Email", value: 34),
        ChartDataItem(label: "Phone Call", value: 28)
      ],
      bySentiment: [
        ChartDataItem(label: "Positive", value: 52),
        ChartDataItem(label: "Neutral", value: 28)
      ]
    )

    mockService.stubbedPipeline = [
      ChartDataItem(label: "Initial Contact", value: 250),
      ChartDataItem(label: "Active Discussions", value: 85),
      ChartDataItem(label: "Offers", value: 15),
      ChartDataItem(label: "Committed", value: 3)
    ]

    mockService.stubbedSchoolAnalytics = [
      ChartDataItem(label: "Active Recruiting", value: 18),
      ChartDataItem(label: "On Wait List", value: 4),
      ChartDataItem(label: "Passed", value: 2)
    ]

    mockService.stubbedPerformanceCorrelation = [
      PerformanceCorrelationResponse.CorrelationDataSet(
        label: "Exit Velocity vs Distance",
        points: [
          PerformanceCorrelationResponse.CorrelationPoint(x: 85.0, y: 340.0, label: "Player A"),
          PerformanceCorrelationResponse.CorrelationPoint(x: 90.0, y: 380.0, label: "Player B")
        ]
      )
    ]
  }
}
