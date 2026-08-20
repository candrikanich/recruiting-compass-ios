import Foundation

/// COMPUTED formatters — 1:1 port of the web `COMPUTED` map + metrics/event helpers
/// (utils/templateResolver.ts). Scalars + metrics register into `TemplateResolver.computed`;
/// event helpers feed `TemplateContextBuilder.buildDerived`.
enum TemplateComputed {
  private static func s(_ v: String?) -> String? {
    guard let t = v?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
    return t
  }
  private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  /// US 10-digit phone → "(216) 534-8996" (also handles a leading country-code 1);
  /// anything else is returned trimmed and unchanged. Mirrors web `formatUsPhone`.
  static func usPhone(_ raw: String?) -> String? {
    guard let raw = s(raw) else { return nil }
    let digits = raw.filter(\.isNumber)
    let core: String
    if digits.count == 11, digits.hasPrefix("1") { core = String(digits.dropFirst()) }
    else if digits.count == 10 { core = digits }
    else { return raw }
    let area = core.prefix(3)
    let mid = core.dropFirst(3).prefix(3)
    let last = core.dropFirst(6)
    return "(\(area)) \(mid)-\(last)"
  }

  private static func utcCalendar() -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
  }

  // MARK: - Scalars

  static let scalars: [String: @Sendable (ResolverContext) -> String?] = [
    "playerFirstName": { c in
      guard let full = s(c.tables["users"]?["full_name"]) else { return nil }
      return full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
    },
    "height": { c in
      guard let raw = c.prefs["height_inches"], let d = Double(raw) else { return nil }
      let n = Int(d)
      return "\(n / 12)'\(n % 12)\""
    },
    "weight": { c in
      guard let w = s(c.prefs["weight_lbs"]) else { return nil }
      return "\(w) lbs"
    },
    "coachSalutation": { c in
      guard let last = s(c.tables["coaches"]?["last_name"]) else { return nil }
      return "Coach \(last)"
    },
    "schoolShortName": { c in
      guard let name = s(c.tables["schools"]?["name"]) else { return nil }
      let stripped = name.replacingOccurrences(
        of: #"\s+(University|College)$"#, with: "",
        options: [.regularExpression, .caseInsensitive]
      ).trimmingCharacters(in: .whitespaces)
      return stripped.isEmpty ? name.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) : stripped
    },
    // Optional completion sentence — renders only when the school's recruiting
    // questionnaire is marked complete. Returns nil otherwise; `renderClean`
    // strips the unresolved optional token so the surrounding line collapses.
    // Mirrors web `COMPUTED.questionnaireNote` (utils/templateResolver.ts). The
    // trailing space keeps the following sentence spaced when present.
    "questionnaireNote": { c in
      c.tables["schools"]?["questionnaire_completed"] == "true"
        ? "I've completed your recruiting questionnaire. "
        : nil
    },
    "testLabel": { c in
      if s(c.prefs["act_score"]) != nil { return "ACT" }
      if s(c.prefs["sat_score"]) != nil { return "SAT" }
      return nil
    },
    "testScore": { c in
      s(c.prefs["act_score"]) ?? s(c.prefs["sat_score"])
    },
    "seasonLabel": { c in
      let m = utcCalendar().component(.month, from: c.now) - 1   // 0-indexed to match JS getUTCMonth()
      if m <= 1 || m == 11 { return "winter" }
      if m <= 4 { return "spring" }
      if m <= 7 { return "summer" }
      return "fall"
    },
    "todayDate": { c in
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US")
      f.timeZone = TimeZone(identifier: "UTC")
      f.dateFormat = "MMMM d, yyyy"
      return f.string(from: c.now)
    }
  ]

  // MARK: - Metrics

  private static func humanizeMetricLabel(_ metricType: String?) -> String {
    (metricType ?? "").replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
  }

  private static func nf(_ d: Double) -> String {
    d == d.rounded() ? String(Int(d)) : String(d)
  }

  private static func metricDisplay(_ m: TemplateMetricRow) -> String {
    if let dv = m.displayValue?.trimmingCharacters(in: .whitespaces), !dv.isEmpty { return dv }
    if let v = m.value { return "\(nf(v))\(m.unit.map { " \($0)" } ?? "")" }
    return ""
  }

  /// Accepts ISO date-time or date-only ("2026-07-22").
  static func parseDate(_ iso: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    if let d = f.date(from: iso) { return d }
    let dOnly = DateFormatter()
    dOnly.locale = Locale(identifier: "en_US_POSIX")
    dOnly.timeZone = TimeZone(identifier: "UTC")
    dOnly.dateFormat = "yyyy-MM-dd"
    return dOnly.date(from: String(iso.prefix(10)))
  }

  static func monthYear(_ iso: String?) -> String? {
    guard let iso, let d = parseDate(iso) else { return nil }
    let cal = utcCalendar()
    return "\(months[cal.component(.month, from: d) - 1]) \(cal.component(.year, from: d))"
  }

  /// Collapses multiple rows of the same metric_type down to the single most
  /// recent by `recorded_date`. Ties fall back to verified, then primary, then
  /// input order — so an athlete with several 60-times shows only their latest.
  private static func dedupeMostRecentPerType(_ metrics: [TemplateMetricRow]) -> [TemplateMetricRow] {
    var best: [String: (offset: Int, row: TemplateMetricRow)] = [:]
    for (idx, m) in metrics.enumerated() {
      let typeKey = m.metricType ?? ""
      guard let existing = best[typeKey] else {
        best[typeKey] = (idx, m)
        continue
      }
      let e = existing.row
      let mDate = m.recordedDate ?? "", eDate = e.recordedDate ?? ""
      let mWins: Bool
      if mDate != eDate {
        mWins = mDate > eDate
      } else if (m.verified ?? false) != (e.verified ?? false) {
        mWins = m.verified ?? false
      } else if (m.isPrimary ?? false) != (e.isPrimary ?? false) {
        mWins = m.isPrimary ?? false
      } else {
        mWins = false   // keep the earlier row (stable)
      }
      if mWins { best[typeKey] = (idx, m) }
    }
    return best.values.sorted { $0.offset < $1.offset }.map(\.row)
  }

  private static func rankMetrics(_ metrics: [TemplateMetricRow]) -> [TemplateMetricRow] {
    metrics.enumerated().sorted { lhs, rhs in
      let a = lhs.element, b = rhs.element
      if (a.isPrimary ?? false) != (b.isPrimary ?? false) { return a.isPrimary ?? false }
      if (a.verified ?? false) != (b.verified ?? false) { return a.verified ?? false }
      let ad = a.recordedDate ?? "", bd = b.recordedDate ?? ""
      if ad != bd { return ad > bd }
      return lhs.offset < rhs.offset   // stable
    }.map(\.element)
  }

  static func renderMetrics(_ metrics: [TemplateMetricRow], cap: Int = 4) -> String {
    rankMetrics(dedupeMostRecentPerType(metrics)).prefix(cap).map { m in
      let label = humanizeMetricLabel(m.metricType)
      let provenance = [m.source, monthYear(m.recordedDate)].compactMap { $0 }.joined(separator: ", ")
      let tail = provenance.isEmpty ? "" : " (\(provenance))"
      let head = label.isEmpty ? "" : "\(label): "
      return "- \(head)\(metricDisplay(m))\(tail)"
    }.joined(separator: "\n")
  }

  static func carryingTool(_ metrics: [TemplateMetricRow]) -> String? {
    guard let primary = metrics.first(where: { $0.isPrimary ?? false }) else { return nil }
    let label = humanizeMetricLabel(primary.metricType)
    let value = metricDisplay(primary)
    let joined = [value, label].filter { !$0.isEmpty }.joined(separator: " ")
    return joined.isEmpty ? nil : joined
  }

  static let metrics: [String: @Sendable (ResolverContext) -> String?] = [
    "metrics": { c in let b = renderMetrics(c.metrics); return b.isEmpty ? nil : b },
    "carryingTool": { c in carryingTool(c.metrics) },
    "metricsAsOf": { c in
      let dates = c.metrics.compactMap { $0.recordedDate }.filter { !$0.isEmpty }.sorted()
      guard let latest = dates.last else { return nil }
      return monthYear(latest)
    }
  ]

  // MARK: - Events

  private static func monthDay(_ iso: String?) -> String? {
    guard let iso, let d = parseDate(iso) else { return nil }
    let cal = utcCalendar()
    return "\(months[cal.component(.month, from: d) - 1]) \(cal.component(.day, from: d))"
  }

  private static func eventLocation(_ e: EventLite) -> String? {
    let cityState = [e.city, e.state].compactMap { s($0) }.joined(separator: ", ")
    return cityState.isEmpty ? s(e.location) : cityState
  }

  /// Upcoming (end/start today or later), soonest first, capped.
  static func selectUpcomingEvents(_ events: [EventLite], now: Date, cap: Int = 5) -> [EventLite] {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd"
    let today = f.string(from: now)
    return events
      .filter { e in
        let end = (e.endDate?.isEmpty == false ? e.endDate : e.startDate)
        guard let end else { return false }
        return String(end.prefix(10)) >= today
      }
      .sorted { ($0.startDate ?? "") < ($1.startDate ?? "") }
      .prefix(cap)
      .map { $0 }
  }

  static func renderEventSchedule(_ events: [EventLite], now: Date = Date(), cap: Int = 5) -> String? {
    let rows = selectUpcomingEvents(events, now: now, cap: cap).compactMap { e -> String? in
      let date = monthDay(e.startDate)
      let name = s(e.name)
      if date == nil && name == nil { return nil }
      let head = [date, name].compactMap { $0 }.joined(separator: " — ")
      let loc = eventLocation(e)
      return "- \(head)\(loc.map { ", \($0)" } ?? "")"
    }
    return rows.isEmpty ? nil : rows.joined(separator: "\n")
  }

  static func nextEvent(_ events: [EventLite], now: Date = Date()) -> (name: String?, dates: String?)? {
    guard let next = selectUpcomingEvents(events, now: now, cap: 1).first else { return nil }
    let start = monthDay(next.startDate)
    let end = monthDay(next.endDate)
    let dates: String?
    if let start, let end, end != start { dates = "\(start)–\(end)" } else { dates = start }
    return (name: s(next.name), dates: dates)
  }
}
