import SwiftUI

struct AnalyticsDashboardView: View {
  @State private var viewModel: AnalyticsDashboardViewModel
  @State private var exportFileURL: URL?
  @State private var showShareSheet = false

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
          .accessibilityLabel("Export analytics data")
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
    .sheet(isPresented: $showShareSheet) {
      if let url = exportFileURL {
        ActivityShareSheet(activityItems: [url])
      }
    }
    .task {
      await viewModel.loadAllData()
    }
    .refreshable {
      await viewModel.loadAllData()
    }
  }

  // MARK: - Dashboard Content

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

        if viewModel.hasInteractionData {
          PieChartView(
            segments: viewModel.interactionTypesData,
            title: "Interaction Types"
          )
          .padding(.horizontal)
        }

        if viewModel.hasSentimentData {
          PieChartView(
            segments: viewModel.sentimentData,
            title: "Sentiment Breakdown"
          )
          .padding(.horizontal)
        }

        if viewModel.hasPipelineData {
          FunnelChartView(
            stages: viewModel.pipelineData,
            title: "Recruiting Pipeline"
          )
          .padding(.horizontal)
        }

        if viewModel.hasSchoolData {
          PieChartView(
            segments: viewModel.schoolStatusData,
            title: "School Status Distribution"
          )
          .padding(.horizontal)
        }

        if let scatterData = viewModel.performanceData, viewModel.hasPerformanceData {
          ScatterChartView(
            dataSet: scatterData,
            title: "Performance Correlation"
          )
          .padding(.horizontal)
        }
      }
      .padding(.vertical)
    }
  }

  // MARK: - Sections

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

  private var summaryStatsSection: some View {
    LazyVGrid(columns: [
      GridItem(.flexible()),
      GridItem(.flexible())
    ], spacing: 12) {
      ForEach(viewModel.summaryCards) { card in
        StatCardView(card: card)
      }
    }
    .padding(.horizontal)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Summary statistics")
  }

  // MARK: - States

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.2)
      Text("Loading analytics...")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityLabel("Loading analytics dashboard")
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
      .accessibilityLabel("Retry loading analytics")
      .accessibilityHint("Double tap to retry loading analytics data")
    }
  }

  private var emptyStateView: some View {
    ContentUnavailableView {
      Label("No Data to Analyze", systemImage: "chart.bar.xaxis")
    } description: {
      Text("Start adding schools and logging interactions to see analytics")
    }
    .accessibilityLabel("No analytics data available yet")
  }

  // MARK: - Custom Date Picker

  private var customDatePickerSheet: some View {
    NavigationStack {
      Form {
        DatePicker(
          "Start Date",
          selection: $viewModel.customStartDate,
          in: ...Date.now,
          displayedComponents: .date
        )
        .accessibilityLabel("Start date for custom range")

        DatePicker(
          "End Date",
          selection: $viewModel.customEndDate,
          in: ...Date.now,
          displayedComponents: .date
        )
        .accessibilityLabel("End date for custom range")
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
      exportFileURL = url
      showShareSheet = true
    }
  }
}

#Preview {
  NavigationStack {
    AnalyticsDashboardView()
  }
}
