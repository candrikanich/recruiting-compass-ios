import Foundation

/// Who may see a purchase surface. Fails closed: anything not known to need a plan sees none.
@MainActor
enum PaywallAccess {
  /// Founding and complimentary families never see a paywall; neither does a plan this build cannot read (`unknown`)
  /// or one that has not loaded. The `paywall` kill switch hides it for everyone without a release.
  static func isAvailable(subscription: FamilySubscription?, flags: FeatureFlagStore?) -> Bool {
    guard flags.isEnabled(.paywall), let subscription else { return false }
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
    holdsSubscription: Bool
  ) -> [PlanAction] {
    guard isAvailable(subscription: subscription, flags: flags), let subscription else { return [] }
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

enum PlanAction: Equatable {
  case seePlans, changePlan, manageSubscription
}
