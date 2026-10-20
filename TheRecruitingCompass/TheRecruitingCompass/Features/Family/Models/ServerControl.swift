import Foundation

/// How a Remove/Leave control looks, derived only from the server's verdict (`canRemove`/`canLeave` plus its
/// reason). A missing verdict hides the control: iOS never decides on its own that an action is allowed.
struct ServerControl: Equatable {
  let allowed: Bool?
  let blockedReason: String?

  var isEnabled: Bool { allowed == true }

  /// Shown when allowed, or when the server blocked it and said why.
  var isVisible: Bool { isEnabled || reason != nil }

  var reason: String? {
    guard !isEnabled, let text = blockedReason, !text.isEmpty else { return nil }
    return text
  }
}
