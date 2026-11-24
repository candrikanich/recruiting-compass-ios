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
  /// For a parent, who can renew. Web (web#1234) copies it word for word.
  static let subscriptionMessage = String(
    localized: "Your plan is read-only right now. Renew your subscription to add or change anything."
  )
  /// For everyone else (an athlete is often a minor and cannot buy in the app, Chris 2026-11-24): no price, no
  /// pressure, and the same ask-a-parent line the Plan screen shows.
  static let askAParentMessage = String(
    localized: "Your plan is read-only right now. A parent can choose a plan for your family."
  )

  /// Only a parent is told to renew; a missing role fails closed to the neutral line.
  static func message(for role: UserRole?) -> String {
    role == .parent ? subscriptionMessage : askAParentMessage
  }

  /// Decides blocking: true only when the plan is known to be read-only, so a writable family is never blocked.
  static let viewPlanButton = String(localized: "View plan")
  static let closeButton = String(localized: "Close")

  @ObservationIgnored var isReadOnly: @MainActor () -> Bool = { false }
  /// Decides mapping of a refused write: true whenever the plan is not known to be writable (loading, failed load,
  /// read-only). The server has already refused by then, so "permission denied" would only mislead. Falls back to
  /// `isReadOnly` for a screen that is not wired to the store.
  @ObservationIgnored var cannotWrite: (@MainActor () -> Bool)?
  /// Who is asking, so the notice can tell a parent to renew and anyone else to ask a parent. Re-read on every use.
  @ObservationIgnored var role: @MainActor () -> UserRole? = { nil }
  var isShowingNotice = false

  /// The notice text for whoever is signed in now.
  var noticeMessage: String { Self.message(for: role()) }

  /// Reads the plan from the app's entitlement store: blocks on a known read-only plan, maps on any unwritable one.
  func attach(to store: EntitlementStore, role: @escaping @MainActor () -> UserRole?) {
    isReadOnly = { store.isReadOnly }
    cannotWrite = { !store.canWrite }
    self.role = role
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
    return noticeMessage
  }
}
