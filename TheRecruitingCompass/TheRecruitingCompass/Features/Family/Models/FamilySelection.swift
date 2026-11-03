import Foundation

/// Which family a multi-family parent is working in. Pure so the default can be pinned against web.
enum FamilySelection {
  /// A family the parent can switch to; `label` is the server's player-based family label (#368).
  struct Choice: Identifiable, Equatable {
    let id: String
    let label: String
  }

  /// The saved family while the parent still belongs to it; otherwise web's server-side default
  /// (`pickPrimaryFamilyUnitId`): the most recently joined family that has a player, else the most recently joined.
  /// `memberships` must be ordered most recently joined first.
  static func resolve(
    memberships: [FamilyMember],
    familyIdsWithPlayer: Set<String>,
    savedFamilyId: String?
  ) -> String? {
    let ids = memberships.map(\.familyUnitId)
    if let savedFamilyId, ids.contains(savedFamilyId) { return savedFamilyId }
    return ids.first { familyIdsWithPlayer.contains($0) } ?? ids.first
  }

  static func choices(memberships: [FamilyMember], labels: [String: String]) -> [Choice] {
    var seen = Set<String>()
    return memberships.compactMap { member in
      guard seen.insert(member.familyUnitId).inserted else { return nil }
      return Choice(
        id: member.familyUnitId,
        label: labels[member.familyUnitId] ?? String(localized: "Family")
      )
    }
  }
}
