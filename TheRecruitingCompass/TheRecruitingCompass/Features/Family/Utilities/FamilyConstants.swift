import Foundation

enum FamilyConstants {
  enum Spacing {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
    static let icon: CGFloat = 48
  }

  enum Duration {
    static let successToast: Swift.Duration = .seconds(3)
  }

  enum Validation {
    static let codePattern = "^FAM-[A-Z0-9]{6}$"
  }

  /// Sports list for parent onboarding (replicated from web parent flow).
  ///
  /// Derived from `CanonicalPositions.bySport` (the iOS single source of truth)
  /// rather than hardcoded, so it can never drift out of parity with the athlete
  /// onboarding vocabulary again. Sorted alphabetically for a stable picker
  /// order, with an "Other" catch-all appended for parents whose athlete's sport
  /// isn't listed. A test asserts this stays in sync with the position registry.
  enum Sports {
    static let all: [String] = CanonicalPositions.bySport.keys.sorted() + ["Other"]
  }
}
