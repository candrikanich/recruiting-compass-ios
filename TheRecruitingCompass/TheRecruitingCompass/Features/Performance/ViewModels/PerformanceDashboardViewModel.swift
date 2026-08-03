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

  nonisolated deinit {}
  var metrics: [PerformanceMetric] = [] {
    didSet { recomputeDerivedMetrics() }
  }
  var isLoading = false
  var errorMessage: String?
  var showAddForm = false
  var showEditSheet = false
  var editingMetric: PerformanceMetric?
  var showExportSheet = false
  var showDeleteConfirmation = false
  var metricToDelete: PerformanceMetric?
  var selectedMetricType: MetricType? {
    didSet { recomputeDerivedMetrics() }
  }
  var successMessage: String?
  var showSuccessToast = false
  var addFormState = MetricFormState()
  var editFormState = MetricFormState()
  var isSubmitting = false
  var isDeleting = false

  let performanceService: any PerformanceManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  /// The user whose metrics we read/write. When a parent is viewing an
  /// athlete, metrics belong to the athlete (mirrors web +
  /// OffersListViewModel); otherwise the logged-in user's own id.
  private var targetUserId: String? {
    familyManager.selectedAthlete?.userId ?? authManager.user?.id
  }
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter
  }()

  // MARK: - Computed Properties

  /// Cached derived state — recomputed via `recomputeDerivedMetrics()` whenever
  /// `metrics` or `selectedMetricType` change. Do not compute these inline
  /// elsewhere; they would go stale silently.
  private(set) var sortedMetrics: [PerformanceMetric] = []
  private(set) var availableMetricTypes: [MetricType] = []
  private(set) var activeMetricType: MetricType?
  private(set) var chartMetrics: [PerformanceMetric] = []
  private(set) var latestMetricsByType: [MetricType: PerformanceMetric] = [:]
  private(set) var metricTrends: [MetricTrend] = []

  var hasEnoughDataForChart: Bool {
    chartMetrics.count >= 2
  }

  private func recomputeDerivedMetrics() {
    sortedMetrics = metrics.sorted { $0.recordedDate > $1.recordedDate }

    let types = Set(metrics.map(\.metricType))
    availableMetricTypes = MetricType.allCases.filter { types.contains($0) }

    activeMetricType = selectedMetricType ?? availableMetricTypes.first

    if let type = activeMetricType {
      chartMetrics = metrics
        .filter { $0.metricType == type }
        .sorted { $0.recordedDate < $1.recordedDate }
    } else {
      chartMetrics = []
    }

    var latest: [MetricType: PerformanceMetric] = [:]
    for metric in sortedMetrics where latest[metric.metricType] == nil {
      latest[metric.metricType] = metric
    }
    latestMetricsByType = latest

    let typeGroups = Dictionary(grouping: metrics, by: \.metricType)
    metricTrends = typeGroups
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

  private let cache: (any CacheManaging)?

  /// TTL for cached metrics list (seconds).
  private static let metricsListCacheTTL: TimeInterval = 60

  init(
    performanceService: (any PerformanceManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.performanceService = performanceService ?? PerformanceServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
  }

  /// Invalidates the cached metrics list so the next `loadMetrics()` refetches.
  /// Call after any mutation (create, update, delete). `EventDetailViewModel.addMetric()`
  /// invalidates the same key (via `ListCacheKeys.metrics`) for metrics logged
  /// inline from an event's quick-log form.
  private func invalidateMetricsListCache() async {
    guard let userId = targetUserId else { return }
    await (cache ?? InMemoryCache.shared).remove(forKey: ListCacheKeys.metrics(userId: userId))
  }

  // MARK: - Actions

  func loadMetrics() async {
    guard let userId = targetUserId else {
      logger.warning("No authenticated user")
      errorMessage = "Please sign in to view performance metrics."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    let cacheKey = ListCacheKeys.metrics(userId: userId)
    let cacheToUse = cache ?? InMemoryCache.shared

    do {
      if let cached = await cacheToUse.get([PerformanceMetric].self, forKey: cacheKey) {
        metrics = cached
        logger.info("Loaded \(self.metrics.count) metrics from cache")
      } else {
        let fetched = try await performanceService.fetchMetrics(userId: userId)
        metrics = fetched
        await cacheToUse.set(fetched, forKey: cacheKey, ttlSeconds: Self.metricsListCacheTTL)
        logger.info("Loaded \(self.metrics.count) metrics")
      }
    } catch {
      logger.error("Failed to load metrics: \(error.localizedDescription)")
      errorMessage = "Failed to load metrics. Please try again."
    }
  }

  func addMetric() async {
    guard let userId = targetUserId else { return }
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
      await invalidateMetricsListCache()
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
      await invalidateMetricsListCache()
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
      await invalidateMetricsListCache()
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

}
