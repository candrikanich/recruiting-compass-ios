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
  enum Sports {
    static let all: [String] = [
      "Baseball",
      "Basketball",
      "Football",
      "Lacrosse",
      "Soccer",
      "Softball",
      "Swimming",
      "Track & Field",
      "Volleyball",
      "Wrestling",
      "Golf",
      "Tennis",
      "Cross Country",
      "Other"
    ]
  }
}
