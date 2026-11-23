import Foundation

/// Decides whether the dashboard's verify-email banner shows. A minor awaiting guardian consent sees only the
/// guardian banner; the verify prompt waits for the guardian lookup so it never flashes first, and returns once
/// consent lands. A failed lookup counts as loaded and unlocked, so the prompt is never lost to a network error.
enum EmailVerificationBannerVisibility {
  /// `guardian` is nil for members with no guardian lookup, who are never held back.
  static func isVisible(
    isVerified: Bool,
    isDismissed: Bool,
    guardian: (loaded: Bool, locked: Bool)?
  ) -> Bool {
    guard !isVerified, !isDismissed else { return false }
    guard let guardian else { return true }
    return guardian.loaded && !guardian.locked
  }

  /// Only athletes have a guardian lookup; for anyone else it never runs, so waiting on it would hide the prompt
  /// forever.
  @MainActor
  static func guardian(for member: FamilyMember?, lookup: GuardianStatusViewModel) -> GuardianStatusViewModel? {
    member?.isAthlete == true ? lookup : nil
  }
}
