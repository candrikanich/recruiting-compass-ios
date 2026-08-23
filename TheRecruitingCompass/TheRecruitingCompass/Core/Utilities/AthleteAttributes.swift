import Foundation

/// Per-sport athlete handedness/laterality attributes (Bats, Shoots, Dominant
/// Foot, …). Swift mirror of web `utils/attributes/canonical.ts`. Values are flat
/// keys stored in `user_preferences.data` (category `player`) — ZERO DB migration.
///
/// Every `key`, option token, and position-gate label MUST stay byte-identical
/// with web (see `planning/2026-08-22-phase3-registry-contract.md`, Registry A).
/// Only `label`/`optionLabels` are presentation.
enum AthleteAttributes {
  /// One handedness/laterality attribute an athlete can set.
  struct AttributeDef: Equatable, Sendable {
    /// Flat storage key (e.g. `shooting_hand`) — matches the PlayerDetails field.
    let key: String
    /// Display label for the picker header.
    let label: String
    /// Stored option tokens in display order (e.g. `["L", "R", "S"]`).
    let options: [String]
    /// token → display label (e.g. `"L": "Left"`).
    let optionLabels: [String: String]
    /// Position-gate: attribute renders only when the athlete's primaryPosition is
    /// in this list (canonical position LABELS from `CanonicalPositions`). Empty =
    /// show for every athlete of the sport.
    let positions: [String]
  }

  /// Attributes per sport, keyed by the sport strings used across
  /// onboarding/preferences (matching `CanonicalPositions.bySport`). Sports with
  /// no laterality attribute (Track & Field, Cross Country, Swimming, Wrestling,
  /// Field Hockey) are intentionally absent.
  static let bySport: [String: [AttributeDef]] = [
    "Baseball": batsThrows,
    "Softball": batsThrows,
    "Basketball": [
      AttributeDef(key: "shooting_hand", label: String(localized: "Shooting Hand"),
                   options: leftRight, optionLabels: leftRightLabels, positions: [])
    ],
    "Soccer": [
      AttributeDef(key: "dominant_foot", label: String(localized: "Dominant Foot"),
                   options: ["L", "R", "Both"],
                   optionLabels: ["L": String(localized: "Left"), "R": String(localized: "Right"),
                                  "Both": String(localized: "Both")],
                   positions: [])
    ],
    "Volleyball": [
      AttributeDef(key: "hitting_hand", label: String(localized: "Hitting Arm"),
                   options: leftRight, optionLabels: leftRightLabels, positions: [])
    ],
    "Tennis": [
      AttributeDef(key: "racket_hand", label: String(localized: "Plays"),
                   options: leftRight,
                   optionLabels: ["L": String(localized: "Left-handed"),
                                  "R": String(localized: "Right-handed")],
                   positions: []),
      AttributeDef(key: "backhand_style", label: String(localized: "Backhand"),
                   options: ["one", "two"],
                   optionLabels: ["one": String(localized: "One-handed"),
                                  "two": String(localized: "Two-handed")],
                   positions: [])
    ],
    "Golf": [
      AttributeDef(key: "golf_handedness", label: String(localized: "Plays"),
                   options: leftRight,
                   optionLabels: ["L": String(localized: "Left-handed"),
                                  "R": String(localized: "Right-handed")],
                   positions: [])
    ],
    "Lacrosse": [
      AttributeDef(key: "dominant_hand", label: String(localized: "Dominant Hand"),
                   options: leftRight, optionLabels: leftRightLabels, positions: [])
    ],
    "Ice Hockey": [
      AttributeDef(key: "shoots", label: String(localized: "Shoots"),
                   options: leftRight, optionLabels: leftRightLabels, positions: []),
      AttributeDef(key: "catches", label: String(localized: "Catches (Goalie)"),
                   options: leftRight, optionLabels: leftRightLabels, positions: ["Goalie"])
    ],
    "Water Polo": [
      AttributeDef(key: "wp_dominant_hand", label: String(localized: "Dominant Hand"),
                   options: leftRight, optionLabels: leftRightLabels, positions: [])
    ],
    "Rowing": [
      AttributeDef(key: "rowing_side", label: String(localized: "Rigging Side"),
                   options: ["port", "starboard", "both", "cox"],
                   optionLabels: ["port": String(localized: "Port"),
                                  "starboard": String(localized: "Starboard"),
                                  "both": String(localized: "Both"),
                                  "cox": String(localized: "Coxswain")],
                   positions: []),
      AttributeDef(key: "rowing_discipline", label: String(localized: "Discipline"),
                   options: ["sweep", "scull", "both"],
                   optionLabels: ["sweep": String(localized: "Sweep"),
                                  "scull": String(localized: "Sculling"),
                                  "both": String(localized: "Both")],
                   positions: [])
    ],
    "Football": [
      AttributeDef(key: "throwing_hand", label: String(localized: "Throwing Hand"),
                   options: leftRight, optionLabels: leftRightLabels, positions: ["Quarterback"]),
      AttributeDef(key: "kicking_foot", label: String(localized: "Kicking Foot"),
                   options: leftRight, optionLabels: leftRightLabels, positions: ["Kicker", "Punter"])
    ]
  ]

  /// Attributes for a sport (case-insensitive). Empty for nil/unknown sports and
  /// for sports with no laterality attribute — mirrors
  /// `CanonicalPositions.positions(for:)`.
  static func attributes(for sport: String?) -> [AttributeDef] {
    guard let sport else { return [] }
    return bySport.first { $0.key.caseInsensitiveCompare(sport) == .orderedSame }?.value ?? []
  }

  // MARK: - Shared option tables

  private static let leftRight = ["L", "R"]
  private static let leftRightLabels = ["L": String(localized: "Left"), "R": String(localized: "Right")]

  private static let batsThrows: [AttributeDef] = [
    AttributeDef(key: "bats", label: String(localized: "Bats"),
                 options: ["L", "R", "S"],
                 optionLabels: ["L": String(localized: "Left"), "R": String(localized: "Right"),
                                "S": String(localized: "Switch")],
                 positions: []),
    AttributeDef(key: "throws", label: String(localized: "Throws"),
                 options: leftRight, optionLabels: leftRightLabels, positions: [])
  ]
}
