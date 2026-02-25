import SwiftUI
import Charts

struct PerformanceDashboardView: View {
  @State private var viewModel: PerformanceDashboardViewModel

  init(viewModel: PerformanceDashboardViewModel? = nil) {
    _viewModel = State(initialValue: viewModel ?? PerformanceDashboardViewModel())
  }

  var body: some View {
    Group {
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
          .accessibilityLabel("Export metrics")
        }

        Button {
          viewModel.showAddForm = true
        } label: {
          Label("Log Metric", systemImage: "plus")
        }
        .accessibilityLabel("Log new metric")
      }
    }
    .sheet(isPresented: $viewModel.showAddForm) {
      NavigationStack {
        ScrollView {
          MetricFormView(
            formState: $viewModel.addFormState,
            title: "Log Performance Metric",
            submitLabel: "Log Metric",
            isSubmitting: viewModel.isSubmitting,
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
            title: "Edit Performance Metric",
            submitLabel: "Save Changes",
            isSubmitting: viewModel.isSubmitting,
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

  private var metricsContent: some View {
    ScrollView {
      LazyVStack(spacing: 24) {
        chartSection
        if !viewModel.metricTrends.isEmpty {
          trendsSection
        }
        latestMetricsSection
        historySection
      }
      .padding()
    }
  }

  private var chartSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Performance Trends")
          .font(.title3)
          .fontWeight(.bold)
        Spacer()
      }

      if viewModel.availableMetricTypes.count > 1 {
        MetricTypeFilterBar(
          availableTypes: viewModel.availableMetricTypes,
          selectedType: $viewModel.selectedMetricType
        )
      }

      PerformanceChartView(
        metrics: viewModel.chartMetrics,
        metricType: viewModel.activeMetricType
      )
    }
    .padding()
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
  }

  private var trendsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Metric Trends")
        .font(.title3)
        .fontWeight(.bold)

      ForEach(viewModel.metricTrends) { trend in
        TrendCard(trend: trend)
      }
    }
  }

  private var latestMetricsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Latest Metrics")
        .font(.title3)
        .fontWeight(.bold)

      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
      ], spacing: 12) {
        ForEach(
          Array(viewModel.latestMetricsByType.values)
            .sorted(by: { $0.metricType.displayName < $1.metricType.displayName })
        ) { metric in
          LatestMetricCard(metric: metric)
        }
      }
    }
  }

  private var historySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Metric History")
        .font(.title3)
        .fontWeight(.bold)

      ForEach(viewModel.sortedMetrics) { metric in
        MetricHistoryCard(
          metric: metric,
          onEdit: { viewModel.startEditing(metric) },
          onDelete: { viewModel.confirmDelete(metric) }
        )
      }
    }
  }

  // MARK: - States

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.2)
      Text("Loading metrics...")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityLabel("Loading performance metrics")
  }

  private var emptyStateView: some View {
    ContentUnavailableView {
      Label("No Metrics Logged", systemImage: "chart.xyaxis.line")
    } description: {
      Text("Start tracking your performance to build a historical record")
    } actions: {
      Button {
        viewModel.showAddForm = true
      } label: {
        Label("Log Metric", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityLabel("Log your first metric")
    }
  }
}

// MARK: - Supporting Views

struct SuccessToast: View {
  let message: String

  var body: some View {
    Text(message)
      .font(.subheadline)
      .fontWeight(.medium)
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(Color.successGreen)
      .clipShape(Capsule())
      .shadow(radius: 4)
      .padding(.bottom, 20)
      .accessibilityLabel(message)
  }
}

#Preview {
  NavigationStack {
    PerformanceDashboardView()
  }
  .environment(AuthManager.shared)
}
