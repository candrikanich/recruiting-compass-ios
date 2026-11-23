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

  @ObservationIgnored var isReadOnly: @MainActor () -> Bool = { false }
  var isShowingNotice = false

  /// True when the write must not go ahead; shows the subscription notice.
  func blocksWrite() -> Bool {
    guard isReadOnly() else { return false }
    isShowingNotice = true
    return true
  }

  /// The subscription message for a permission failure on a read-only plan, nil for every other error.
  func subscriptionMessage(for error: Error) -> String? {
    guard isReadOnly(), isPermissionDenied(error) else { return nil }
    return Self.subscriptionMessage
  }
}
