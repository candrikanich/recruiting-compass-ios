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
    static let successToast: UInt64 = 3_000_000_000
  }

  enum Validation {
    static let codePattern = "^FAM-[A-Z0-9]{6}$"
  }
}
