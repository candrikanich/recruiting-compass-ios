import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "PerformanceDashboardViewModel"
)

@Observable
@MainActor
final class PerformanceDashboardViewModel {
  var metrics: [PerformanceMetric] = []
  var isLoading = false
  var errorMessage: String?
  var showAddForm = false
  var showEditSheet = false
  var editingMetric: PerformanceMetric?
  var showExportSheet = false
  var showDeleteConfirmation = false
  var metricToDelete: PerformanceMetric?
  var selectedMetricType: MetricType?
  var successMessage: String?
  var showSuccessToast = false
  var addFormState = MetricFormState()
  var editFormState = MetricFormState()
  var isSubmitting = false
  var isDeleting = false

  let performanceService: any PerformanceManaging
  private let authManager: any AuthManaging
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter
  }()

  // MARK: - Computed Properties

  var sortedMetrics: [PerformanceMetric] {
    metrics.sorted { $0.recordedDate > $1.recordedDate }
  }

  var availableMetricTypes: [MetricType] {
    let types = Set(metrics.map(\.metricType))
    return MetricType.allCases.filter { types.contains($0) }
  }

  var activeMetricType: MetricType? {
    selectedMetricType ?? availableMetricTypes.first
  }

  var chartMetrics: [PerformanceMetric] {
    guard let type = activeMetricType else { return [] }
    return metrics
      .filter { $0.metricType == type }
      .sorted { $0.recordedDate < $1.recordedDate }
  }

  var hasEnoughDataForChart: Bool {
    chartMetrics.count >= 2
  }

  var latestMetricsByType: [MetricType: PerformanceMetric] {
    var result: [MetricType: PerformanceMetric] = [:]
    let sorted = sortedMetrics
    for metric in sorted where result[metric.metricType] == nil {
      result[metric.metricType] = metric
    }
    return result
  }

  var metricTrends: [MetricTrend] {
    let typeGroups = Dictionary(grouping: metrics, by: \.metricType)

    return typeGroups
      .filter { $0.value.count >= 2 }
      .compactMap { type, records in
        let sorted = records.sorted { $0.recordedDate < $1.recordedDate }
        let values = Array(sorted.map(\.value).suffix(10))

        guard let minVal = values.min(), let maxVal = values.max() else { return nil }

        let avg = values.reduce(0, +) / Double(values.count)
        let trend = calculateTrend(values: values, type: type)
        let unit = sorted.first?.unit ?? ""

        return MetricTrend(
          type: type,
          values: values,
          min: (minVal * 100).rounded() / 100,
          max: (maxVal * 100).rounded() / 100,
          average: (avg * 100).rounded() / 100,
          unit: unit,
          count: values.count,
          trend: trend
        )
      }
      .sorted { $0.type.displayName < $1.type.displayName }
  }

  // MARK: - Init

  init(
    performanceService: (any PerformanceManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.performanceService = performanceService ?? PerformanceServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  // MARK: - Actions

  func loadMetrics() async {
    guard let userId = authManager.user?.id else {
      logger.warning("No authenticated user")
      errorMessage = "Please sign in to view performance metrics."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      metrics = try await performanceService.fetchMetrics(userId: userId)
      logger.info("Loaded \(self.metrics.count) metrics")
    } catch {
      logger.error("Failed to load metrics: \(error.localizedDescription)")
      errorMessage = "Failed to load metrics. Please try again."
    }
  }

  func addMetric() async {
    guard let userId = authManager.user?.id else { return }
    guard addFormState.isValid, let parsedValue = addFormState.parsedValue else { return }
    guard let type = addFormState.metricType else { return }

    isSubmitting = true
    defer { isSubmitting = false }

    let request = MetricCreateRequest(
      metricType: type.rawValue,
      value: parsedValue,
      unit: addFormState.unit.isEmpty ? type.defaultUnit : addFormState.unit,
      recordedDate: Self.dateFormatter.string(from: addFormState.recordedDate),
      verified: addFormState.verified,
      notes: addFormState.notes.isEmpty ? nil : addFormState.notes
    )

    do {
      let newMetric = try await performanceService.createMetric(userId: userId, request: request)
      metrics.append(newMetric)
      addFormState.reset()
      showAddForm = false
      successMessage = "Metric logged successfully"
      showSuccessToast = true
      logger.info("Metric added: \(newMetric.id)")
    } catch {
      logger.error("Failed to add metric: \(error.localizedDescription)")
      errorMessage = "Failed to log metric. Please try again."
    }
  }

  func startEditing(_ metric: PerformanceMetric) {
    editingMetric = metric
    editFormState.populate(from: metric)
    showEditSheet = true
  }

  func updateMetric() async {
    guard let metric = editingMetric else { return }
    guard editFormState.isValid, let parsedValue = editFormState.parsedValue else { return }
    guard let type = editFormState.metricType else { return }

    isSubmitting = true
    defer { isSubmitting = false }

    let request = MetricUpdateRequest(
      metricType: type.rawValue,
      value: parsedValue,
      unit: editFormState.unit.isEmpty ? type.defaultUnit : editFormState.unit,
      recordedDate: Self.dateFormatter.string(from: editFormState.recordedDate),
      verified: editFormState.verified,
      notes: editFormState.notes.isEmpty ? nil : editFormState.notes
    )

    do {
      let updated = try await performanceService.updateMetric(id: metric.id, request: request)
      if let index = metrics.firstIndex(where: { $0.id == metric.id }) {
        metrics[index] = updated
      }
      showEditSheet = false
      editingMetric = nil
      successMessage = "Metric updated successfully"
      showSuccessToast = true
      logger.info("Metric updated: \(metric.id)")
    } catch {
      logger.error("Failed to update metric: \(error.localizedDescription)")
      errorMessage = "Failed to update metric. Please try again."
    }
  }

  func confirmDelete(_ metric: PerformanceMetric) {
    metricToDelete = metric
    showDeleteConfirmation = true
  }

  func deleteMetric() async {
    guard let metric = metricToDelete else { return }
    guard !isDeleting else { return }

    isDeleting = true
    defer { isDeleting = false }

    do {
      try await performanceService.deleteMetric(id: metric.id)
      metrics.removeAll { $0.id == metric.id }
      metricToDelete = nil
      showDeleteConfirmation = false
      successMessage = "Metric deleted"
      showSuccessToast = true
      logger.info("Metric deleted: \(metric.id)")
    } catch {
      logger.error("Failed to delete metric: \(error.localizedDescription)")
      errorMessage = "Failed to delete metric. Please try again."
    }
  }

  // MARK: - Trend Calculation (matches web: first 3 vs last 3 comparison)

  func calculateTrend(values: [Double], type: MetricType) -> MetricTrend.TrendDirection {
    guard values.count >= 2 else { return .stable }

    let first3 = Array(values.prefix(3))
    let last3 = Array(values.suffix(3))
    let firstAvg = first3.reduce(0, +) / Double(first3.count)
    let lastAvg = last3.reduce(0, +) / Double(last3.count)

    guard firstAvg > 0 else { return .stable }

    if type.isLowerBetter {
      if lastAvg < firstAvg * 0.99 { return .improving }
      if lastAvg > firstAvg * 1.01 { return .declining }
    } else {
      if lastAvg > firstAvg * 1.01 { return .improving }
      if lastAvg < firstAvg * 0.99 { return .declining }
    }

    return .stable
  }

  // MARK: - Export

  func generateCSV() -> String {
    var csv = "Metric Type,Value,Unit,Date,Verified,Notes\n"
    for metric in sortedMetrics {
      let notes = (metric.notes ?? "").replacingOccurrences(of: ",", with: ";")
      csv += "\(metric.metricType.displayName),\(metric.value),\(metric.unit),\(metric.formattedDate),\(metric.verified),\(notes)\n"
    }
    return csv
  }

  func generatePDF() -> Data {
    let generator = PerformancePDFGenerator()
    let userName = authManager.user?.email
    return generator.generate(metrics: sortedMetrics, userName: userName)
  }

  nonisolated deinit {}
}
