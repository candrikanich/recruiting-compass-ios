import Foundation

/// Maps a suggestion's `action_type` to the primary CTA shown on its card.
/// Unknown types and nil have no iOS CTA — the card shows Learn More only.
enum ActionItemCTA: Equatable {
  case addSchool
  case logInteraction
  case addVideo
  case updateVideo
  case none

  init(actionType: String?) {
    switch actionType {
    case "add_school": self = .addSchool
    case "log_interaction": self = .logInteraction
    case "add_video": self = .addVideo
    case "update_video": self = .updateVideo
    default: self = .none
    }
  }

  var label: String? {
    switch self {
    case .addSchool: return String(localized: "Add School")
    case .logInteraction: return String(localized: "Log Interaction")
    case .addVideo: return String(localized: "Add Video")
    case .updateVideo: return String(localized: "Update Video")
    case .none: return nil
    }
  }
}
