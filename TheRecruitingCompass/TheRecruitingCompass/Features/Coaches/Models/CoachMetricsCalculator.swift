import Foundation

/// Per-coach communication metrics. Port of the web `CoachMetrics`
/// (composables/useCoachAnalytics.ts) — keep the two in sync.
struct CoachMetrics: Sendable, Equatable {
  let totalInteractions: Int
  let responseRate: Int            // percentage
  let averageResponseTime: Double  // hours
  let lastContactDate: Date?
  let daysSinceContact: Int        // -1 when never contacted
  let preferredMethod: String
  let outboundCount: Int
  let inboundCount: Int
}

/// A coach ranked against the school's other coaches by response rate.
struct CoachComparison: Sendable, Equatable {
  let coach: CoachMetrics
  let schoolAverageResponseRate: Int
  let rank: Int
  let totalCoaches: Int
}

/// Pure analytics helpers — mirror of web `utils`/`useCoachAnalytics` pure
/// functions. Input arrays are assumed newest-first (the query order), matching
/// the web behavior, so both platforms compute identically.
enum CoachMetricsCalculator {

  /// Metrics for one coach from an interactions array. Safe on empty/partial data.
  static func metrics(for coachId: String, in interactions: [Interaction]) -> CoachMetrics {
    let coachInteractions = interactions.filter { $0.coachId == coachId }

    let outboundCount = coachInteractions.filter { $0.direction == .outbound }.count
    let inboundCount = coachInteractions.filter { $0.direction == .inbound }.count

    let responseRate = outboundCount > 0
      ? Double(inboundCount) / Double(outboundCount) * 100
      : 0

    // Average response time: pair each outbound with the next inbound that follows
    // it in the array (mirrors the web loop over the newest-first list).
    var totalResponseTime: TimeInterval = 0
    var responseCount = 0
    if coachInteractions.count > 1 {
      for i in 0..<(coachInteractions.count - 1) {
        let current = coachInteractions[i]
        guard current.direction == .outbound else { continue }
        if let nextInbound = coachInteractions[(i + 1)...].first(where: { $0.direction == .inbound }) {
          totalResponseTime += nextInbound.displayDate.timeIntervalSince(current.displayDate)
          responseCount += 1
        }
      }
    }
    let averageResponseTime = responseCount > 0
      ? (totalResponseTime / Double(responseCount) / 3600 * 10).rounded() / 10
      : 0

    let lastContact = coachInteractions.first?.displayDate
    let daysSinceContact: Int = {
      guard let lastContact else { return -1 }
      return max(0, Calendar.current.dateComponents([.day], from: lastContact, to: .now).day ?? 0)
    }()

    // Preferred method = most frequent inbound type.
    let inboundInteractions = coachInteractions.filter { $0.direction == .inbound }
    var typeCounts: [InteractionType: Int] = [:]
    for interaction in inboundInteractions {
      typeCounts[interaction.type, default: 0] += 1
    }
    var topType: InteractionType?
    var topCount = 0
    for (type, count) in typeCounts where count > topCount {
      topType = type
      topCount = count
    }
    let preferredMethod = topType?.displayName ?? InteractionType.email.displayName

    return CoachMetrics(
      totalInteractions: coachInteractions.count,
      responseRate: Int(responseRate.rounded()),
      averageResponseTime: averageResponseTime,
      lastContactDate: lastContact,
      daysSinceContact: daysSinceContact,
      preferredMethod: preferredMethod,
      outboundCount: outboundCount,
      inboundCount: inboundCount
    )
  }

  /// Rank this coach against the school's other coaches by response rate.
  static func comparison(
    for coachId: String,
    schoolId: String?,
    interactions: [Interaction],
    coaches: [Coach]
  ) -> CoachComparison? {
    guard let schoolId else { return nil }

    let coachMetrics = metrics(for: coachId, in: interactions)
    let schoolCoaches = coaches.filter { $0.schoolId == schoolId }
    let schoolMetrics = schoolCoaches.map { metrics(for: $0.id, in: interactions) }

    let avgResponseRate = schoolMetrics.isEmpty
      ? 0
      : Int((Double(schoolMetrics.reduce(0) { $0 + $1.responseRate }) / Double(schoolMetrics.count)).rounded())

    return CoachComparison(
      coach: coachMetrics,
      schoolAverageResponseRate: avgResponseRate,
      rank: schoolMetrics.filter { $0.responseRate > coachMetrics.responseRate }.count + 1,
      totalCoaches: schoolMetrics.count
    )
  }

  /// Human-readable insights derived from a coach's metrics.
  static func insights(for coachId: String, in interactions: [Interaction]) -> [String] {
    let m = metrics(for: coachId, in: interactions)
    var out: [String] = []

    if m.daysSinceContact > 30 {
      out.append(String(localized: "No contact in \(m.daysSinceContact) days - consider reaching out"))
    }

    if m.averageResponseTime > 48 {
      out.append(String(localized: "Average response time is \(formatHours(m.averageResponseTime)) hours - slow responder"))
    } else if m.averageResponseTime > 0 && m.averageResponseTime < 24 {
      out.append(String(localized: "Quick responder - average \(formatHours(m.averageResponseTime)) hours"))
    }

    if m.inboundCount > 0 {
      out.append(String(localized: "Prefers responding via \(m.preferredMethod)"))
    }

    return out
  }

  private static func formatHours(_ hours: Double) -> String {
    hours == hours.rounded() ? String(Int(hours)) : String(hours)
  }
}
