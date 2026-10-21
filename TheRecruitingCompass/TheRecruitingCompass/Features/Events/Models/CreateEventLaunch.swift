import Foundation

/// Opening Create Event from a surface whose family id may still be loading (the Dashboard widget).
/// The form is only ever presented with a real family id: a tap before it arrives waits, and every way the
/// wait can end (family arrives, load fails, user leaves) leaves `isWaiting` false.
struct CreateEventLaunch: Equatable {
  enum Phase: Equatable {
    case idle
    case waitingForFamily
    case presenting(familyUnitId: String)
    case failed
  }

  private(set) var phase: Phase = .idle

  var isWaiting: Bool { phase == .waitingForFamily }

  mutating func tap(familyUnitId: String?, membership: FamilyMembershipStatus) {
    phase = Self.phase(familyUnitId: familyUnitId, membership: membership, whileWaiting: .waitingForFamily)
  }

  mutating func retry(membership: FamilyMembershipStatus) {
    guard phase == .failed else { return }
    phase = membership == .failed ? .failed : .waitingForFamily
  }

  /// Completes a tap that was parked while the family loaded; a change with no pending tap never opens the form.
  mutating func familyChanged(familyUnitId: String?, membership: FamilyMembershipStatus) {
    guard phase == .waitingForFamily else { return }
    phase = Self.phase(familyUnitId: familyUnitId, membership: membership, whileWaiting: .waitingForFamily)
  }

  mutating func cancel() {
    if phase == .waitingForFamily { phase = .idle }
  }

  /// Ignored while waiting: only `cancel()` ends a wait, so an alert's auto-dismiss can't undo a Retry.
  mutating func dismiss() {
    if phase != .waitingForFamily { phase = .idle }
  }

  /// `.none` goes idle: the family-required gate takes over, so no separate no-family copy here (ios#390 re-scope).
  private static func phase(
    familyUnitId: String?, membership: FamilyMembershipStatus, whileWaiting: Phase
  ) -> Phase {
    if let id = FamilyUnitID.normalized(familyUnitId) { return .presenting(familyUnitId: id) }
    switch membership {
    case .failed: return .failed
    case .none: return .idle
    case .unknown, .member: return whileWaiting
    }
  }
}
