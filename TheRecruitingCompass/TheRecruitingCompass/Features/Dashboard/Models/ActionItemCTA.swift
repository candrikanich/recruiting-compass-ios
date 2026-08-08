import Foundation

/// Maps a suggestion's `action_type` to the primary CTA shown on its card.
/// Video actions (`add_video`/`update_video`), unknown types, and nil have no
/// iOS CTA today — the card shows Learn More only (see Path B).
enum ActionItemCTA: Equatable {
  case addSchool
  case logInteraction
  case none

  init(actionType: String?) {
    switch actionType {
    case "add_school": self = .addSchool
    case "log_interaction": self = .logInteraction
    default: self = .none
    }
  }

  var label: String? {
    switch self {
    case .addSchool: return String(localized: "Add School")
    case .logInteraction: return String(localized: "Log Interaction")
    case .none: return nil
    }
  }
}
