import Foundation

/// Constants for onboarding flow. Mirrors web onboarding index.vue.
enum OnboardingConstants {
  static let totalSteps = 5

  static let commonSports: [String] = [
    "Baseball", "Basketball", "Football", "Soccer", "Volleyball", "Softball",
    "Track & Field", "Swimming", "Cross Country", "Tennis", "Golf", "Lacrosse",
    "Field Hockey", "Ice Hockey", "Wrestling", "Rowing", "Water Polo"
  ]

  static let sportPositions: [String: [String]] = [
    "Baseball": ["Pitcher", "Catcher", "Infielder", "Outfielder", "Designated Hitter"],
    "Basketball": ["Point Guard", "Shooting Guard", "Small Forward", "Power Forward", "Center"],
    "Football": ["Quarterback", "Running Back", "Wide Receiver", "Tight End", "Offensive Line", "Linebacker", "Defensive Back", "Defensive Line"],
    "Soccer": ["Goalkeeper", "Defender", "Midfielder", "Forward"],
    "Volleyball": ["Outside Hitter", "Middle Blocker", "Setter", "Libero", "Opposite Hitter"],
    "Softball": ["Pitcher", "Catcher", "Infielder", "Outfielder", "Designated Hitter"],
    "Track & Field": ["Sprinter", "Distance Runner", "Jumper", "Thrower"],
    "Swimming": ["Freestyle", "Backstroke", "Breaststroke", "Butterfly", "Individual Medley"],
    "Cross Country": ["Runner"],
    "Tennis": ["Singles", "Doubles"],
    "Golf": ["Golfer"],
    "Lacrosse": ["Attackman", "Midfielder", "Defenseman", "Goalie"],
    "Field Hockey": ["Forward", "Midfielder", "Defender", "Goalkeeper"],
    "Ice Hockey": ["Forward", "Defenseman", "Goalie"],
    "Wrestling": ["Wrestler"],
    "Rowing": ["Rower"],
    "Water Polo": ["Field Player", "Goalkeeper"],
    "Other": ["Other"]
  ]

  static var graduationYears: [Int] {
    GradeLevelHelper.allowedGraduationYears
  }
}
