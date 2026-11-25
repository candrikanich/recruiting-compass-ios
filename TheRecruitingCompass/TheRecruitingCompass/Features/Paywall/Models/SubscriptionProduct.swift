import Foundation

/// A `trc_access` subscription product, decoded from its App Store product id (runbook §3.1).
/// Ids that do not match are not ours to sell and never reach the picker.
struct SubscriptionProduct: Equatable, Hashable, Sendable {
  enum Kind: String, Sendable { case players, addl }
  enum Period: String, CaseIterable, Sendable { case annual, monthly }

  let id: String
  let kind: Kind
  /// Paid player seats. The top tiers (`players_4`, `addl_3`) cover any larger family.
  let seats: Int
  let period: Period

  init?(productId: String) {
    let parts = productId.split(separator: "_", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 4, parts[0] == "trc",
      let kind = Kind(rawValue: parts[1]),
      let seats = Int(parts[2]), (1...Self.maxSeats(for: kind)).contains(seats),
      parts[2] == String(seats),
      let period = Period(rawValue: parts[3])
    else { return nil }
    self.id = productId
    self.kind = kind
    self.seats = seats
    self.period = period
  }

  private static func maxSeats(for kind: Kind) -> Int {
    switch kind {
    case .players: 4
    case .addl: 3
    }
  }

  private var isTopTier: Bool { seats == Self.maxSeats(for: kind) }

  var tierTitle: String {
    switch (kind, isTopTier) {
    case (.players, true): String(localized: "\(seats) or more players")
    case (.players, false): playersTitle
    case (.addl, true): String(localized: "\(seats) or more additional players")
    case (.addl, false): additionalTitle
    }
  }

  private var playersTitle: String {
    if seats == 1 { return String(localized: "1 player") }
    return String(localized: "\(seats) players")
  }

  private var additionalTitle: String {
    if seats == 1 { return String(localized: "1 additional player") }
    return String(localized: "\(seats) additional players")
  }
}
