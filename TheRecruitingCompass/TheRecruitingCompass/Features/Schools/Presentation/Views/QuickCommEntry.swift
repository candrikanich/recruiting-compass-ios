import Foundation

/// What the School detail "Quick Comm" action should do. Hidden entirely while `athlete_messages` is off.
enum QuickCommEntry: Equatable {
  case none
  case direct(Coach)
  case pickCoach

  @MainActor
  static func resolve(coaches: [Coach], flags: FeatureFlagStore?) -> QuickCommEntry {
    guard flags.isEnabled(.athleteMessages) else { return .none }
    switch coaches.count {
    case 0: return .none
    case 1: return .direct(coaches[0])
    default: return .pickCoach
    }
  }
}
