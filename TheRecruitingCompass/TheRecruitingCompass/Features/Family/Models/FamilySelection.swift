import Foundation

/// A player (athlete) member of a family; `graduationYear` is nil until the profile has one.
struct FamilyPlayer: Equatable, Sendable {
  let familyUnitId: String
  let graduationYear: Int?
}

/// Which family a multi-family parent is working in. Pure so the default can be pinned against web.
enum FamilySelection {
  /// A family the parent can switch to; `label` is the server's player-based family label (#368).
  struct Choice: Identifiable, Equatable {
    let id: String
    let label: String
  }

  /// The saved family while the parent still belongs to it; otherwise the family whose player is closest to
  /// graduation (lowest year, families without a year last), as the web client does by default. Ties and families
  /// with no year fall back to the most recently joined; a parent with no player in any family gets the most
  /// recently joined one. `memberships` must be ordered most recently joined first.
  static func resolve(
    memberships: [FamilyMember],
    players: [FamilyPlayer],
    savedFamilyId: String?
  ) -> String? {
    let ids = memberships.map(\.familyUnitId)
    if let savedFamilyId, ids.contains(savedFamilyId) { return savedFamilyId }
    let yearByFamily = players.reduce(into: [String: Int]()) { years, player in
      years[player.familyUnitId] = min(years[player.familyUnitId] ?? .max, player.graduationYear ?? .max)
    }
    // `min(by:)` keeps the first of equal elements, i.e. the most recently joined.
    return ids.filter { yearByFamily[$0] != nil }.min { yearByFamily[$0, default: .max] < yearByFamily[$1, default: .max] } ?? ids.first
  }

  /// Families without a server label get "Family 1", "Family 2" so they stay distinguishable (also to VoiceOver).
  static func choices(memberships: [FamilyMember], labels: [String: String]) -> [Choice] {
    var seen = Set<String>()
    let ids = memberships.map(\.familyUnitId).filter { seen.insert($0).inserted }
    return ids.enumerated().map { index, id in
      Choice(id: id, label: labels[id] ?? String(localized: "Family \(index + 1)"))
    }
  }
}
