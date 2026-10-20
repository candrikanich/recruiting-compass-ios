import Foundation

/// Whether the signed-in user belongs to a family. `unknown` (still loading) and `failed` are deliberately
/// distinct from `none`: only a successful zero-membership read may send someone to the create-or-join screen.
enum FamilyMembershipStatus: Equatable {
  case unknown
  case member
  case none
  case failed
}

/// The family-required gate (web `domain/family/familyGate.ts`). Every account must be in a family; a missing one
/// is an invariant violation that routes to the create-or-join screen. Pure, so the rules are testable.
enum FamilyGate {
  enum Route: Equatable {
    case loading
    case passThrough
    case setup
    /// The membership read failed. Neither the app (could be family-less) nor the gate (could have a family).
    case retry
  }

  static func route(for status: FamilyMembershipStatus) -> Route {
    switch status {
    case .unknown: .loading
    case .member: .passThrough
    case .none: .setup
    case .failed: .retry
    }
  }

  /// A failed refresh never demotes a user already known to be in a family; only a first read can fail.
  static func status(afterReading familyUnitId: String?) -> FamilyMembershipStatus {
    familyUnitId == nil ? .none : .member
  }

  static func status(afterFailedReadFrom current: FamilyMembershipStatus) -> FamilyMembershipStatus {
    current == .member ? .member : .failed
  }

  /// Pending, unexpired invitations addressed to `email` (case-insensitive). Declined, accepted and expired
  /// ones are ignored, as are other people's, which RLS can also return to a member of the sender's family.
  static func validPendingInvitations(
    _ invitations: [FamilyInvitation], email: String?, now: Date
  ) -> [FamilyInvitation] {
    guard let email = email?.trimmingCharacters(in: .whitespaces).lowercased(), !email.isEmpty else { return [] }
    return invitations.filter {
      $0.isPending
        && $0.invitedEmail.trimmingCharacters(in: .whitespaces).lowercased() == email
        && !isExpired($0.expiresAt, now: now)
    }
  }

  /// With a valid pending invite the user must JOIN: the screen shows a notice and no "Create my family".
  /// Join-by-code stays either way.
  static func offersCreate(invitations: [FamilyInvitation], email: String?, now: Date) -> Bool {
    validPendingInvitations(invitations, email: email, now: now).isEmpty
  }

  private static func isExpired(_ expiresAt: String?, now: Date) -> Bool {
    guard let expiresAt, !expiresAt.isEmpty, let date = parse(expiresAt) else { return false }
    return date <= now
  }

  private static func parse(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }
}

/// Sign-out offered on every gate screen so a user whose session was revoked elsewhere is never stuck.
enum GateSignOut {
  /// Returns an error message to show, or nil on success.
  @MainActor
  static func perform(using authManager: any AuthManaging) async -> String? {
    do {
      try await authManager.logout()
      return nil
    } catch {
      return error.localizedDescription
    }
  }
}
