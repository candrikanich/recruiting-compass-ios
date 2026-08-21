import SwiftUI
import Charts

struct PerformanceDashboardView: View {
  @State private var viewModel: PerformanceDashboardViewModel

  init(viewModel: PerformanceDashboardViewModel? = nil) {
    _viewModel = State(initialValue: viewModel ?? PerformanceDashboardViewModel())
  }

  var body: some View {
    VStack(spacing: 0) {
      if let errorMessage = viewModel.errorMessage {
        ErrorBanner(message: errorMessage) { viewModel.errorMessage = nil }
          .padding(.horizontal)
      }

      if viewModel.isLoading && viewModel.metrics.isEmpty {
        loadingView
      } else if viewModel.metrics.isEmpty {
        emptyStateView
      } else {
        metricsContent
      }
    }
    .navigationTitle("Performance Metrics")
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        if !viewModel.metrics.isEmpty {
          Button {
            viewModel.showExportSheet = true
          } label: {
            Label("Export", systemImage: "square.and.arrow.up")
          }
          .accessibilityLabel(String(localized: "Export metrics"))
        }

        Button {
          viewModel.showAddForm = true
        } label: {
          Label("Log Metric", systemImage: "plus")
        }
        .accessibilityLabel(String(localized: "Log new metric"))
      }
    }
    .sheet(isPresented: $viewModel.showAddForm) {
      NavigationStack {
        ScrollView {
          MetricFormView(
            formState: $viewModel.addFormState,
            title: String(localized: "Log Performance Metric"),
            submitLabel: String(localized: "Log Metric"),
            isSubmitting: viewModel.isSubmitting,
            sport: viewModel.playerSport,
            onSubmit: { Task { await viewModel.addMetric() } },
            onCancel: { viewModel.showAddForm = false }
          )
        }
        .navigationTitle("Log Metric")
        .navigationBarTitleDisplayMode(.inline)
      }
      .presentationDetents([.large])
    }
    .sheet(isPresented: $viewModel.showEditSheet) {
      NavigationStack {
        ScrollView {
          MetricFormView(
            formState: $viewModel.editFormState,
            title: String(localized: "Edit Performance Metric"),
            submitLabel: String(localized: "Save Changes"),
            isSubmitting: viewModel.isSubmitting,
            sport: viewModel.playerSport,
            onSubmit: { Task { await viewModel.updateMetric() } },
            onCancel: {
              viewModel.showEditSheet = false
              viewModel.editingMetric = nil
            }
          )
        }
        .navigationTitle("Edit Metric")
        .navigationBarTitleDisplayMode(.inline)
      }
      .presentationDetents([.large])
    }
    .sheet(isPresented: $viewModel.showExportSheet) {
      ExportFormatSheet(
        csvData: viewModel.generateCSV().data(using: .utf8) ?? Data(),
        pdfData: viewModel.generatePDF()
      )
      .presentationDetents([.medium])
    }
    .alert("Delete Metric", isPresented: $viewModel.showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        Task { await viewModel.deleteMetric() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure you want to delete this metric? This action cannot be undone.")
    }
    .overlay(alignment: .bottom) {
      if viewModel.showSuccessToast, let message = viewModel.successMessage {
        SuccessToast(message: message)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .task(id: viewModel.showSuccessToast) {
            guard viewModel.showSuccessToast else { return }
            try? await Task.sleep(for: .seconds(2))
            withAnimation { viewModel.showSuccessToast = false }
          }
      }
    }
    .task {
      await viewModel.loadMetrics()
    }
    .refreshable {
      await viewModel.loadMetrics()
    }
  }

  // MARK: - Content Sections

  @ViewBuilder
  private var metricsContent: some View {
    ScrollView {
      LazyVStack(spacing: 24) {
        PerformanceChartSection(
          availableMetricTypes: viewModel.availableMetricTypes,
          selectedMetricType: $viewModel.selectedMetricType,
          chartMetrics: viewModel.chartMetrics,
          activeMetricType: viewModel.activeMetricType
        )
        if !viewModel.metricTrends.isEmpty {
          PerformanceTrendsSection(metricTrends: viewModel.metricTrends)
        }
        PerformanceLatestMetricsSection(
          latestMetricsByType: viewModel.latestMetricsByType
        )
        PerformanceHistorySection(
          sortedMetrics: viewModel.sortedMetrics,
          onEdit: { viewModel.startEditing($0) },
          onDelete: { viewModel.confirmDelete($0) },
          onTogglePrimary: { metric in Task { await viewModel.togglePrimary(metric) } }
        )
      }
      .padding()
    }
  }

  // MARK: - States

  @ViewBuilder
  private var loadingView: some View {
    LoadingStateView(message: "Loading metrics...")
      .accessibilityLabel(String(localized: "Loading performance metrics"))
  }

  @ViewBuilder
  private var emptyStateView: some View {
    EmptyStateView(
      icon: "chart.xyaxis.line",
      title: String(localized: "No Metrics Logged"),
      message: String(localized: "Start tracking your performance to build a historical record"),
      actionTitle: String(localized: "Log Your First Metric"),
      actionHint: String(localized: "Opens the form to log a performance metric")
    ) {
      viewModel.showAddForm = true
    }
    .frame(maxHeight: .infinity)
  }
}

// MARK: - Private Section Structs

private struct PerformanceChartSection: View {
  let availableMetricTypes: [MetricType]
  @Binding var selectedMetricType: MetricType?
  let chartMetrics: [PerformanceMetric]
  let activeMetricType: MetricType?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Performance Trends")
          .font(.title3)
          .bold()
        Spacer()
      }

      if availableMetricTypes.count > 1 {
        MetricTypeFilterBar(
          availableTypes: availableMetricTypes,
          selectedType: $selectedMetricType
        )
      }

      PerformanceChartView(
        metrics: chartMetrics,
        metricType: activeMetricType
      )
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .brandShadowSm()
  }
}

private struct PerformanceTrendsSection: View {
  let metricTrends: [MetricTrend]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Metric Trends")
        .font(.title3)
        .bold()

      ForEach(metricTrends) { trend in
        TrendCard(trend: trend)
      }
    }
  }
}

private struct PerformanceLatestMetricsSection: View {
  /// Sorted once at init rather than re-sorted inside the ForEach initializer
  /// on every body evaluation.
  private let sortedMetrics: [PerformanceMetric]

  init(latestMetricsByType: [MetricType: PerformanceMetric]) {
    self.sortedMetrics = Array(latestMetricsByType.values)
      .sorted(by: { $0.metricType.displayName < $1.metricType.displayName })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Latest Metrics")
        .font(.title3)
        .bold()

      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
      ], spacing: 12) {
        ForEach(sortedMetrics) { metric in
          LatestMetricCard(metric: metric)
        }
      }
    }
  }
}

private struct PerformanceHistorySection: View {
  let sortedMetrics: [PerformanceMetric]
  let onEdit: (PerformanceMetric) -> Void
  let onDelete: (PerformanceMetric) -> Void
  let onTogglePrimary: (PerformanceMetric) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Metric History")
        .font(.title3)
        .bold()

      ForEach(sortedMetrics) { metric in
        MetricHistoryCard(
          metric: metric,
          onEdit: { onEdit(metric) },
          onDelete: { onDelete(metric) },
          onTogglePrimary: { onTogglePrimary(metric) }
        )
      }
    }
  }
}

#Preview {
  NavigationStack {
    PerformanceDashboardView()
  }
  .environment(AuthManager.shared)
}
