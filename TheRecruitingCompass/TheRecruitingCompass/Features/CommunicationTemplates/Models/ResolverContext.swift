import Foundation

/// One performance_metrics row for the resolver (optional cols the shared PerformanceMetric lacks).
struct TemplateMetricRow: Decodable, Sendable {
  let metricType: String?
  let value: Double?
  let unit: String?
  let displayValue: String?
  let isPrimary: Bool?
  let verified: Bool?
  let recordedDate: String?
  let source: String?

  init(metricType: String?, value: Double? = nil, unit: String? = nil, displayValue: String? = nil,
       isPrimary: Bool? = nil, verified: Bool? = nil, recordedDate: String? = nil, source: String? = nil) {
    self.metricType = metricType
    self.value = value
    self.unit = unit
    self.displayValue = displayValue
    self.isPrimary = isPrimary
    self.verified = verified
    self.recordedDate = recordedDate
    self.source = source
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    metricType = try c.decodeIfPresent(String.self, forKey: .metricType)
    value = try c.decodeIfPresent(Double.self, forKey: .value)
    unit = try c.decodeIfPresent(String.self, forKey: .unit)
    displayValue = try c.decodeIfPresent(String.self, forKey: .displayValue)
    isPrimary = try c.decodeIfPresent(Bool.self, forKey: .isPrimary)
    verified = try c.decodeIfPresent(Bool.self, forKey: .verified)
    recordedDate = try c.decodeIfPresent(String.self, forKey: .recordedDate)
    source = try c.decodeIfPresent(String.self, forKey: .source)
  }

  enum CodingKeys: String, CodingKey {
    case value, unit, verified, source
    case metricType = "metric_type"
    case displayValue = "display_value"
    case isPrimary = "is_primary"
    case recordedDate = "recorded_date"
  }
}

/// Minimal event shape for schedule/next-event formatting.
struct EventLite: Sendable {
  let name: String?
  let startDate: String?
  let endDate: String?
  let location: String?
  let city: String?
  let state: String?
  let url: String?
}

/// Gathered athlete + selected-entity context. String values only; nil/empty omitted upstream.
struct ResolverContext: Sendable {
  var tables: [String: [String: String]]   // "users"/"schools"/"coaches"/"events"
  var prefs: [String: String]               // player prefs jsonb, flattened
  var locationPrefs: [String: String]       // location prefs jsonb (home city/state/zip), flattened
  var authored: [String: String]            // per-message typed values (empty in 2a)
  var derived: [String: String]             // computed-in-context values (sport, hsCoachName, …)
  var metrics: [TemplateMetricRow]
  var events: [EventLite]
  var now: Date

  init(tables: [String: [String: String]], prefs: [String: String],
       locationPrefs: [String: String] = [:], authored: [String: String],
       derived: [String: String], metrics: [TemplateMetricRow], events: [EventLite], now: Date) {
    self.tables = tables
    self.prefs = prefs
    self.locationPrefs = locationPrefs
    self.authored = authored
    self.derived = derived
    self.metrics = metrics
    self.events = events
    self.now = now
  }
}
