import Foundation

/// Raw values are the server contract (`app_config.ios_disabled_features`) and are permanent once shipped:
/// older builds in the wild only recognise the keys they were built with.
enum FeatureKey: String, CaseIterable, Sendable {
  case inboundDrafts = "inbound_drafts"
  case guardianClaim = "guardian_claim"
  case familyInvites = "family_invites"
  case athleteMessages = "athlete_messages"
  /// Hides every purchase surface. Builds before the paywall ignore the key, so it is safe to set early.
  case paywall = "paywall"
}
