import SwiftUI

private struct IdentifiableURL: Identifiable {
  let url: URL
  var id: URL { url }
}

struct AnalyticsDashboardView: View {
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var viewModel: AnalyticsDashboardViewModel
  @State private var exportFileURL: IdentifiableURL?

  init(viewModel: AnalyticsDashboardViewModel? = nil) {
    _viewModel = State(initialValue: viewModel ?? AnalyticsDashboardViewModel())
  }

  var body: some View {
    Group {
      if viewModel.isLoading && !viewModel.hasData {
        loadingView
      } else if let error = viewModel.errorMessage, !viewModel.hasData {
        errorView(error)
      } else if !viewModel.hasData {
        emptyStateView
      } else {
        dashboardContent
      }
    }
    .navigationTitle("Analytics Dashboard")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        if viewModel.hasData {
          Button {
            viewModel.showExportSheet = true
          } label: {
            Label("Export", systemImage: "square.and.arrow.up")
          }
          .accessibilityLabel(String(localized: "Export analytics data"))
          .accessibilityHint("Opens export format options")
        }
      }
    }
    .sheet(isPresented: $viewModel.showExportSheet) {
      AnalyticsExportSheet { format in
        handleExport(format)
      }
    }
    .sheet(isPresented: $viewModel.showDatePicker) {
      customDatePickerSheet
    }
    .sheet(item: $exportFileURL) { wrapped in
      ActivityShareSheet(activityItems: [wrapped.url])
    }
    .alert("Export Failed", isPresented: $viewModel.showExportError) {
    } message: {
      Text(viewModel.exportError ?? String(localized: "Couldn't create the export file. Please try again."))
    }
    .task {
      await viewModel.loadAllData()
    }
    .refreshable {
      await viewModel.loadAllData()
    }
  }

  // MARK: - Dashboard Content

  @ViewBuilder
  private var dashboardContent: some View {
    ScrollView {
      LazyVStack(spacing: 20) {
        headerSection

        DateRangeToolbar(
          selectedRange: $viewModel.dateRange,
          showDatePicker: $viewModel.showDatePicker,
          onRangeSelected: { range in
            await viewModel.setDateRange(range)
          }
        )

        summaryStatsSection

        if isWide {
          chartsGrid
        } else {
          chartsStack
        }
      }
      .padding(.vertical)
      .frame(maxWidth: sizeClass == .regular ? 900 : .infinity)
      .frame(maxWidth: .infinity)
    }
  }

  private var isWide: Bool { sizeClass == .regular }

  // MARK: - Charts Layout

  @ViewBuilder
  private var chartsStack: some View {
    if viewModel.hasInteractionData {
      PieChartView(
        segments: viewModel.interactionTypesData,
        title: String(localized: "Interaction Types")
      )
      .padding(.horizontal)
    }

    if viewModel.hasSentimentData {
      PieChartView(
        segments: viewModel.sentimentData,
        title: String(localized: "Sentiment Breakdown")
      )
      .padding(.horizontal)
    }

    if viewModel.hasPipelineData {
      FunnelChartView(
        stages: viewModel.pipelineData,
        title: String(localized: "Recruiting Pipeline")
      )
      .padding(.horizontal)
    }

    if viewModel.hasSchoolData {
      PieChartView(
        segments: viewModel.schoolStatusData,
        title: String(localized: "School Status Distribution")
      )
      .padding(.horizontal)
    }

    if let scatterData = viewModel.performanceData, viewModel.hasPerformanceData {
      ScatterChartView(
        dataSet: scatterData,
        title: String(localized: "Performance Correlation")
      )
      .padding(.horizontal)
    }
  }

  @ViewBuilder
  private var chartsGrid: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
      if viewModel.hasInteractionData {
        PieChartView(
          segments: viewModel.interactionTypesData,
          title: String(localized: "Interaction Types")
        )
      }

      if viewModel.hasSentimentData {
        PieChartView(
          segments: viewModel.sentimentData,
          title: String(localized: "Sentiment Breakdown")
        )
      }

      if viewModel.hasSchoolData {
        PieChartView(
          segments: viewModel.schoolStatusData,
          title: String(localized: "School Status Distribution")
        )
      }

      if let scatterData = viewModel.performanceData, viewModel.hasPerformanceData {
        ScatterChartView(
          dataSet: scatterData,
          title: String(localized: "Performance Correlation")
        )
      }
    }
    .padding(.horizontal)

    if viewModel.hasPipelineData {
      FunnelChartView(
        stages: viewModel.pipelineData,
        title: String(localized: "Recruiting Pipeline")
      )
      .padding(.horizontal)
    }
  }

  // MARK: - Sections

  @ViewBuilder
  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Comprehensive recruiting metrics and performance insights")
        .font(.subheadline)
        .foregroundStyle(Color.secondaryText)
        .accessibilityAddTraits(.isHeader)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal)
  }

  @ViewBuilder
  private var summaryStatsSection: some View {
    LazyVGrid(columns: Array(
      repeating: GridItem(.flexible()),
      count: isWide ? 4 : 2
    ), spacing: 12) {
      ForEach(viewModel.summaryCards) { card in
        StatCardView(card: card)
      }
    }
    .padding(.horizontal)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(String(localized: "Summary statistics"))
  }

  // MARK: - States

  @ViewBuilder
  private var loadingView: some View {
    LoadingStateView(message: "Loading analytics...")
      .accessibilityLabel(String(localized: "Loading analytics dashboard"))
  }

  private func errorView(_ message: String) -> some View {
    ContentUnavailableView {
      Label("Unable to Load", systemImage: "exclamationmark.triangle")
    } description: {
      Text(message)
    } actions: {
      Button {
        Task { await viewModel.retry() }
      } label: {
        Label("Retry", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityLabel(String(localized: "Retry loading analytics"))
      .accessibilityHint("Double tap to retry loading analytics data")
    }
  }

  @ViewBuilder
  private var emptyStateView: some View {
    ContentUnavailableView {
      Label("No Data to Analyze", systemImage: "chart.bar.xaxis")
    } description: {
      Text("Start adding schools and logging interactions to see analytics")
    }
    .accessibilityLabel(String(localized: "No analytics data available yet"))
  }

  // MARK: - Custom Date Picker

  @ViewBuilder
  private var customDatePickerSheet: some View {
    NavigationStack {
      Form {
        DatePicker(
          "Start Date",
          selection: $viewModel.customStartDate,
          in: ...Date.now,
          displayedComponents: .date
        )
        .accessibilityLabel(String(localized: "Start date for custom range"))

        DatePicker(
          "End Date",
          selection: $viewModel.customEndDate,
          in: ...Date.now,
          displayedComponents: .date
        )
        .accessibilityLabel(String(localized: "End date for custom range"))
      }
      .navigationTitle("Custom Date Range")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            viewModel.showDatePicker = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Apply") {
            Task { await viewModel.applyCustomDateRange() }
          }
          .accessibilityHint("Applies the selected date range and refreshes analytics")
        }
      }
    }
    .presentationDetents([.medium])
  }

  // MARK: - Export

  private func handleExport(_ format: AnalyticsExportFormat) {
    if let url = viewModel.exportFileURL(format: format) {
      exportFileURL = IdentifiableURL(url: url)
    }
  }
}

#Preview {
  NavigationStack {
    AnalyticsDashboardView()
  }
}
