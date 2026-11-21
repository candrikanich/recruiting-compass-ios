import Foundation

/// Decides whether the dashboard's verify-email banner shows. A minor awaiting guardian consent sees only the
/// guardian banner; the verify prompt waits for the guardian lookup so it never flashes first, and returns once
/// consent lands. A failed lookup counts as loaded and unlocked, so the prompt is never lost to a network error.
enum EmailVerificationBannerVisibility {
  static func isVisible(
    isVerified: Bool,
    isDismissed: Bool,
    awaitsGuardianStatus: Bool,
    guardianLoaded: Bool,
    guardianLocked: Bool
  ) -> Bool {
    guard !isVerified, !isDismissed else { return false }
    guard awaitsGuardianStatus else { return true }
    return guardianLoaded && !guardianLocked
  }
}
