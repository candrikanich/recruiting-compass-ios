import Foundation

enum SubscriptionStatus: String, Codable, Sendable {
  case founding, trialing, active, comp
  case readOnly = "read_only"
  /// Decode-only fallback for statuses this build does not know. Never written back.
  case unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = SubscriptionStatus(rawValue: raw) ?? .unknown
  }
}

enum PlanLabel {
  static let unavailable = String(localized: "Plan unavailable")
}

struct FamilySubscription: Codable, Sendable, Equatable {
  let familyUnitId: String
  let status: SubscriptionStatus
  let source: String
  let trialEndsAt: Date?
  let currentPeriodEnd: Date?

  enum CodingKeys: String, CodingKey {
    case familyUnitId = "family_unit_id"
    case status, source
    case trialEndsAt = "trial_ends_at"
    case currentPeriodEnd = "current_period_end"
  }

  /// Mirrors SQL `family_can_write` exactly. Keep in lockstep with the migration.
  func canWrite(now: Date = .now) -> Bool {
    switch status {
    case .founding, .active, .comp:
      return true
    case .trialing:
      guard let trialEndsAt else { return false }
      return trialEndsAt > now
    case .readOnly, .unknown:
      return false
    }
  }

  func trialDaysLeft(now: Date = .now) -> Int? {
    guard status == .trialing, let trialEndsAt else { return nil }
    let remaining = trialEndsAt.timeIntervalSince(now)
    return max(0, Int((remaining / 86_400).rounded(.up)))
  }

  func planLabel(now: Date = .now) -> String {
    switch status {
    case .founding:
      return String(localized: "Founding Family — free for life")
    case .comp:
      return String(localized: "Complimentary access")
    case .readOnly, .unknown:
      return String(localized: "Read-only — subscription needed")
    case .trialing:
      return String(localized: "Free trial — \(trialDaysLeft(now: now) ?? 0) days left")
    case .active:
      guard let currentPeriodEnd else { return String(localized: "Active") }
      let date = currentPeriodEnd.formatted(date: .abbreviated, time: .omitted)
      return String(localized: "Active — renews \(date)")
    }
  }
}
