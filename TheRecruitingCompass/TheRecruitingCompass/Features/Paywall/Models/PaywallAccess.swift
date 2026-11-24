import Foundation

/// Who may see a purchase surface. Fails closed: anything not known to need a plan sees none.
@MainActor
enum PaywallAccess {
  /// Founding and complimentary families never see a paywall; neither does a plan this build cannot read (`unknown`)
  /// or one that has not loaded. The `paywall` kill switch hides it for everyone without a release.
  ///
  /// Only a parent can buy (Chris, 2026-11-24): an athlete is often a minor. A missing role is treated as not a
  /// parent. With no SDK key (`isConfigured` false) there is nothing to sell, so the surface is hidden too.
  static func isAvailable(
    subscription: FamilySubscription?,
    flags: FeatureFlagStore?,
    role: UserRole?,
    isConfigured: Bool
  ) -> Bool {
    guard isConfigured, role == .parent, flags.isEnabled(.paywall), let subscription else { return false }
    switch subscription.status {
    case .trialing, .readOnly, .active:
      return true
    case .founding, .comp, .unknown:
      return false
    }
  }

  /// What the Plan screen offers. A covered member who is not the payer (`holdsSubscription` false) has nothing to
  /// change or manage: buying again would bill a second subscription for a family already covered.
  static func actions(
    subscription: FamilySubscription?,
    flags: FeatureFlagStore?,
    role: UserRole?,
    isConfigured: Bool,
    holdsSubscription: Bool
  ) -> [PlanAction] {
    guard isAvailable(subscription: subscription, flags: flags, role: role, isConfigured: isConfigured),
      let subscription
    else { return [] }
    switch subscription.status {
    case .trialing, .readOnly:
      return [.seePlans]
    case .active:
      return holdsSubscription ? [.changePlan, .manageSubscription] : []
    case .founding, .comp, .unknown:
      return []
    }
  }
}

extension PaywallAccess {
  /// An athlete whose family needs a plan is pointed to a parent instead of a purchase entry point.
  static func showsAskAParentNote(subscription: FamilySubscription?, role: UserRole?) -> Bool {
    guard role == .player, let subscription else { return false }
    return subscription.status == .trialing || subscription.status == .readOnly
  }

  static let askAParentCopy = String(localized: "A parent can choose a plan for your family.")
}

enum PlanAction: Equatable {
  case seePlans, changePlan, manageSubscription
}
