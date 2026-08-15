import Foundation

/// Canonical, sport-scoped athlete positions. Swift mirror of web
/// `utils/positions/canonical.ts`. Web is the source of truth; the shared DB is
/// already backfilled to these full-name values.
///
/// Recruiting output must name a SPECIFIC position, so vague catch-alls are
/// gone: "Utility"/"Infielder"/"Outfielder" no longer resolve to a canonical
/// value. Unknown/legacy values are PRESERVED on read (never dropped) — backfill
/// migrates them.
enum CanonicalPositions {
  /// One canonical vocabulary per sport (full names, granular). Keys match the
  /// sport strings used across onboarding/preferences.
  static let bySport: [String: [String]] = [
    "Baseball": baseball,
    "Softball": baseball,
    "Basketball": ["Point Guard", "Shooting Guard", "Small Forward", "Power Forward", "Center"],
    "Football": ["Quarterback", "Running Back", "Wide Receiver", "Tight End", "Offensive Line",
                 "Defensive Line", "Linebacker", "Defensive Back", "Kicker", "Punter"],
    "Soccer": ["Goalkeeper", "Defender", "Midfielder", "Forward"],
    "Volleyball": ["Outside Hitter", "Middle Blocker", "Setter", "Libero",
                   "Opposite Hitter", "Defensive Specialist"],
    "Track & Field": ["Sprinter", "Distance Runner", "Jumper", "Thrower", "Hurdler"],
    "Swimming": ["Freestyle", "Backstroke", "Breaststroke", "Butterfly", "Individual Medley", "Diver"],
    "Cross Country": ["Runner"],
    "Tennis": ["Singles", "Doubles"],
    "Golf": ["Golfer"],
    "Lacrosse": ["Attackman", "Midfielder", "Defenseman", "Goalie"],
    "Field Hockey": ["Forward", "Midfielder", "Defender", "Goalkeeper"],
    "Ice Hockey": ["Forward", "Defenseman", "Goalie"],
    "Wrestling": ["Wrestler"],
    "Rowing": ["Rower"],
    "Water Polo": ["Field Player", "Goalkeeper"]
  ]

  private static let baseball = ["Pitcher", "Catcher", "First Base", "Second Base", "Third Base",
                                 "Shortstop", "Left Field", "Center Field", "Right Field",
                                 "Designated Hitter"]

  /// Canonical options for a sport (case-insensitive lookup). Empty when the
  /// sport is nil/unknown (e.g. "Other").
  static func positions(for sport: String?) -> [String] {
    guard let sport else { return [] }
    return lookup(sport) ?? []
  }

  /// Sport-scoped normalization: expand abbreviations, snap already-canonical
  /// values to canonical casing, and PRESERVE unknown values (never drop) —
  /// including de-canonicalized legacy "Utility"/"Infielder"/"Outfielder", which
  /// no longer resolve to anything (backfill migrates them). Collisions are
  /// resolved by sport — `C` = Catcher (baseball) vs Center (basketball), `P` =
  /// Pitcher (baseball) vs Punter (football).
  static func normalize(sport: String?, _ value: String?) -> String? {
    guard let raw = value?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return value }

    let sportKey = sport?.lowercased() ?? ""
    if let expanded = abbreviations[sportKey]?[raw.uppercased()] { return expanded }

    if let match = lookup(sport ?? "")?.first(where: { $0.caseInsensitiveCompare(raw) == .orderedSame }) {
      return match
    }

    return raw
  }

  /// Canonical → short abbreviation for the sport (e.g. "Third Base" → "3B").
  /// Falls back to the full name when the sport has no abbreviation table or the
  /// value isn't a known canonical position.
  static func abbreviation(sport: String?, _ canonical: String) -> String {
    let sportKey = sport?.lowercased() ?? ""
    guard let table = abbreviations[sportKey] else { return canonical }
    return table.first { $0.value.caseInsensitiveCompare(canonical) == .orderedSame }?.key ?? canonical
  }

  /// Ordered primary/secondary from an athlete's ENTERED positions, with the
  /// legacy `primaryPosition` string as a last-resort fallback. Index 0 is
  /// primary; the first later entry that differs is secondary.
  static func primaryAndSecondary(_ positions: [String]?, fallback: String?) -> (primary: String, secondary: String) {
    let list = (positions ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    let primary = (list.first ?? fallback?.trimmingCharacters(in: .whitespaces) ?? "")
    let secondary = list.first { $0 != primary } ?? ""
    return (primary, secondary)
  }

  /// Coach-facing short string from entered positions: first two, abbreviated,
  /// primary first, joined with "/" (e.g. "3B/SS"). Empty when nothing is
  /// entered and no fallback is given.
  static func formatPositionsShort(sport: String?, positions: [String]?, fallback: String?) -> String {
    let (primary, secondary) = primaryAndSecondary(positions, fallback: fallback)
    return [primary, secondary]
      .filter { !$0.isEmpty }
      .map { abbreviation(sport: sport, $0) }
      .joined(separator: "/")
  }

  // MARK: - Private

  private static func lookup(_ sport: String) -> [String]? {
    bySport.first { $0.key.caseInsensitiveCompare(sport) == .orderedSame }?.value
  }

  /// Per-sport abbreviation → canonical, keyed by lowercased sport then
  /// uppercased token. Per-sport scoping resolves `C`/`P` collisions.
  private static let abbreviations: [String: [String: String]] = [
    "baseball": baseballAbbrev,
    "softball": baseballAbbrev,
    "basketball": ["PG": "Point Guard", "SG": "Shooting Guard", "SF": "Small Forward",
                   "PF": "Power Forward", "C": "Center"],
    "football": ["QB": "Quarterback", "RB": "Running Back", "WR": "Wide Receiver",
                 "TE": "Tight End", "OL": "Offensive Line", "DL": "Defensive Line",
                 "LB": "Linebacker", "DB": "Defensive Back", "K": "Kicker", "P": "Punter"],
    "soccer": ["GK": "Goalkeeper", "DEF": "Defender", "MID": "Midfielder", "FWD": "Forward"]
  ]

  private static let baseballAbbrev: [String: String] = [
    "P": "Pitcher", "C": "Catcher", "1B": "First Base", "2B": "Second Base", "3B": "Third Base",
    "SS": "Shortstop", "LF": "Left Field", "CF": "Center Field", "RF": "Right Field",
    "DH": "Designated Hitter"
  ]
}
