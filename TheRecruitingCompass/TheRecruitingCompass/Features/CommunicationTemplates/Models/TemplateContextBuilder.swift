import Foundation

/// Pure derived-value computation (ported from composables/useTemplateResolver.ts).
struct TemplateContextBuilder {
  private static let gradeWords: [Int: String] = [12: "twelfth", 11: "eleventh", 10: "tenth", 9: "ninth"]

  private static func currentGrade(_ gradYear: Int?, now: Date) -> Int? {
    guard let gradYear else { return nil }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let month0 = cal.component(.month, from: now) - 1   // 0-indexed
    let year = cal.component(.year, from: now)
    let schoolYearEnd = month0 >= 7 ? year + 1 : year
    return 12 - (gradYear - schoolYearEnd)
  }

  private static func pickHsCoach(_ prefs: [String: String], gradYear: Int?, now: Date) -> String? {
    let grade = currentGrade(gradYear, now: now)
    let clamped = grade.map { min(12, max(9, $0)) }
    let fallback = [12, 11, 10, 9]
    let order = clamped.map { c in [c] + fallback.filter { $0 != c } } ?? fallback
    for g in order {
      if let word = gradeWords[g],
         let v = prefs["\(word)_grade_coach"]?.trimmingCharacters(in: .whitespaces), !v.isEmpty {
        return v
      }
    }
    return nil
  }

  static func buildDerived(
    prefs: [String: String], positions: [String], metrics: [TemplateMetricRow], events: [EventLite],
    profileSlug: String?, transcriptURL: String?, videoPrimaryURL: String?,
    gradYear: Int?, now: Date
  ) -> [String: String] {
    var d: [String: String] = [:]
    func put(_ key: String, _ value: String?) {
      if let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { d[key] = v }
    }
    let sport = prefs["primary_sport"]
    put("sport", sport)
    // Coach-facing "3B/SS" from the entered, ordered positions[] (index 0 =
    // primary); the legacy primary_position string is only a fallback.
    put("position", CanonicalPositions.formatPositionsShort(
      sport: sport, positions: positions, fallback: prefs["primary_position"]))
    let secondary = CanonicalPositions.primaryAndSecondary(
      positions, fallback: prefs["primary_position"]).secondary
    put("positionSecondary", secondary.isEmpty ? nil : CanonicalPositions.abbreviation(sport: sport, secondary))
    put("hsCoachName", pickHsCoach(prefs, gradYear: gradYear, now: now))
    put("profileLink", profileSlug.map { "/\($0)" })
    put("transcriptLink", transcriptURL)
    put("videoLink", videoPrimaryURL)
    put("eventSchedule", TemplateComputed.renderEventSchedule(events, now: now))
    let next = TemplateComputed.nextEvent(events, now: now)
    put("nextEventName", next?.name)
    put("nextEventDates", next?.dates)
    return d
  }
}
