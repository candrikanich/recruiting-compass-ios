import Foundation
import Observation

/// Per-screen gate for family-scoped writes. A read-only plan stops the write before it is sent and explains why;
/// a write the server refuses anyway while the plan is read-only gets the same explanation, not "permission denied".
///
/// `isReadOnly` defaults to "never" so a screen that is not wired to the entitlement store fails open: the server
/// stays the authority and a writable family is never blocked.
@Observable
@MainActor
final class WriteGate {
  nonisolated deinit {}

  static let noticeTitle = String(localized: "Read-only plan")
  static let subscriptionMessage = String(
    localized: "Your plan is read-only right now. Renew your subscription to add or change anything."
  )

  /// Decides blocking: true only when the plan is known to be read-only, so a writable family is never blocked.
  static let viewPlanButton = String(localized: "View plan")
  static let closeButton = String(localized: "Close")

  @ObservationIgnored var isReadOnly: @MainActor () -> Bool = { false }
  /// Decides mapping of a refused write: true whenever the plan is not known to be writable (loading, failed load,
  /// read-only). The server has already refused by then, so "permission denied" would only mislead. Falls back to
  /// `isReadOnly` for a screen that is not wired to the store.
  @ObservationIgnored var cannotWrite: (@MainActor () -> Bool)?
  var isShowingNotice = false

  /// Reads the plan from the app's entitlement store: blocks on a known read-only plan, maps on any unwritable one.
  func attach(to store: EntitlementStore) {
    isReadOnly = { store.isReadOnly }
    cannotWrite = { !store.canWrite }
  }

  /// True when the write must not go ahead; shows the subscription notice.
  func blocksWrite() -> Bool {
    guard isReadOnly() else { return false }
    isShowingNotice = true
    return true
  }

  /// The subscription message for a permission failure while the plan is not known to be writable, else nil.
  func subscriptionMessage(for error: Error) -> String? {
    guard (cannotWrite ?? isReadOnly)(), isPermissionDenied(error) else { return nil }
    return Self.subscriptionMessage
  }
}
