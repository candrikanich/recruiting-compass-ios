import Foundation

enum ContactWindowState: String, Sendable { case pre, open }

/// One `contact_window_rules` row (global reference config).
struct ContactWindowRule: Codable, Sendable, Equatable {
  let sport: String       // lowercase sport, or "*" for the division default
  let division: String    // D1 | D2 | D3 | NAIA | JUCO
  let ruleKind: String    // date_before_grade | date_after_grade | unrestricted
  let reference: String?  // grade the window anchors to, e.g. "junior"
  let windowDate: String? // display date, e.g. "Aug 1"
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case sport, division, notes, reference
    case ruleKind = "rule_kind"
    case windowDate = "window_date"
  }
}

struct ContactWindowInput {
  var sport: String?
  var division: String?
  var gradYear: Int?
  var today: Date = Date()
}

struct ContactWindowResult: Equatable {
  let state: ContactWindowState
  let opensOn: Date?
  let rule: ContactWindowRule?
}

/// Per-sport / per-division NCAA contact-window logic (1:1 port of web `utils/contactWindow.ts`).
/// Fails OPEN everywhere — a config gap must never gate outreach.
enum ContactWindow {
  private static let gradeByReference: [String: Int] =
    ["freshman": 9, "sophomore": 10, "junior": 11, "senior": 12]
  private static let months: [String: Int] = [
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12]

  /// Parse "Aug 1" / "Sept 15" → (month 1-12, day). Nil if unparseable.
  private static func parseWindowDate(_ raw: String?) -> (month: Int, day: Int)? {
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespaces).lowercased()
      .replacingOccurrences(of: ".", with: "")
    let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
    guard parts.count == 2, let month = months[parts[0]], let day = Int(parts[1]), day > 0
    else { return nil }
    return (month, day)
  }

  static func computeWindowOpenDate(_ rule: ContactWindowRule, gradYear: Int) -> Date? {
    if rule.ruleKind == "unrestricted" { return nil }
    guard let grade = gradeByReference[(rule.reference ?? "").lowercased()],
          let parsed = parseWindowDate(rule.windowDate) else { return nil }
    let endYear = gradYear - (12 - grade)                       // spring the grade completes
    let year = rule.ruleKind == "date_before_grade" ? endYear - 1 : endYear
    return Calendar(identifier: .gregorian).date(
      from: DateComponents(year: year, month: parsed.month, day: parsed.day))
  }

  /// Most specific rule: exact (sport, division) → ("*", division) → nil.
  private static func selectRule(_ rules: [ContactWindowRule],
                                 sport: String?, division: String) -> ContactWindowRule? {
    let sportKey = (sport ?? "").trimmingCharacters(in: .whitespaces).lowercased()
    let forDivision = rules.filter { $0.division == division }
    return forDivision.first { $0.sport.lowercased() == sportKey && !sportKey.isEmpty }
      ?? forDivision.first { $0.sport == "*" }
  }

  static func evaluate(rules: [ContactWindowRule], input: ContactWindowInput) -> ContactWindowResult {
    guard let division = input.division, let gradYear = input.gradYear else {
      return ContactWindowResult(state: .open, opensOn: nil, rule: nil)
    }
    guard let rule = selectRule(rules, sport: input.sport, division: division) else {
      return ContactWindowResult(state: .open, opensOn: nil, rule: nil)
    }
    guard let opensOn = computeWindowOpenDate(rule, gradYear: gradYear) else {
      return ContactWindowResult(state: .open, opensOn: nil, rule: rule)
    }
    return ContactWindowResult(state: input.today < opensOn ? .pre : .open, opensOn: opensOn, rule: rule)
  }

  /// Silent swap: in `open`, hide `pre` templates; in `pre`, hide an `any` template when a
  /// `pre` sibling exists in the same (type, stage) group. Athlete always sees one intro.
  static func filterByWindow<T>(_ templates: [T], state: ContactWindowState,
                                group: (T) -> String, window: (T) -> String?) -> [T] {
    if state == .open {
      return templates.filter { window($0) != "pre" }
    }
    let groupsWithPre = Set(templates.filter { window($0) == "pre" }.map(group))
    return templates.filter { window($0) != "any" || !groupsWithPre.contains(group($0)) }
  }
}
