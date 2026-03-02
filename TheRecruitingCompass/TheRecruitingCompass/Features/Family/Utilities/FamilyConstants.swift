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

  /// Positions list for parent onboarding (common across sports; replicate from web as needed).
  enum Positions {
    static let all: [String] = [
      "Pitcher",
      "Catcher",
      "Infielder",
      "Outfielder",
      "Guard",
      "Forward",
      "Center",
      "Quarterback",
      "Running Back",
      "Wide Receiver",
      "Linebacker",
      "Defensive Back",
      "Lineman",
      "Midfielder",
      "Defender",
      "Goalkeeper",
      "Setter",
      "Outside Hitter",
      "Libero",
      "Other"
    ]
  }
}
