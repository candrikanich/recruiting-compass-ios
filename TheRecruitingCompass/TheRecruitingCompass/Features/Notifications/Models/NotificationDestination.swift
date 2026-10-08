import Foundation

enum NotificationDestination: Hashable, Sendable {
  case coachDetail(id: String)
  case schoolDetail(id: String)
  case interactionDetail(id: String)
  case offerDetail(id: String)
  case eventDetail(id: String)
  /// Reuses the pre-existing `inbound_interaction` notification type for an
  /// unrelated event (a new coach-email draft) — disambiguated by
  /// `relatedEntityType == "inbound_email_draft"`, not by `type`. See
  /// `NotificationDestinationParser`.
  case inboundDraftsList
}

extension NotificationDestination {
  /// nil when the destination's feature is switched off remotely, so a tap lands on the default tab.
  @MainActor
  func gated(by flags: FeatureFlagStore?) -> NotificationDestination? {
    switch self {
    case .inboundDraftsList: return flags.isEnabled(.inboundDrafts) ? self : nil
    default: return self
    }
  }
}
