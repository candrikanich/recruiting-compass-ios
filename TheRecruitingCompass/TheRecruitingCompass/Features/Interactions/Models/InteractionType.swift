import SwiftUI

enum InteractionType: String, Codable, CaseIterable, Sendable {
  case email
  case phoneCall = "phone_call"
  case text
  case inPersonVisit = "in_person_visit"
  case virtualMeeting = "virtual_meeting"
  case camp
  case showcase
  case tweet
  case directMessage = "dm"
  case unknown

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = InteractionType(rawValue: rawValue) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .email: return "Email"
    case .phoneCall: return "Phone Call"
    case .text: return "Text"
    case .inPersonVisit: return "In-Person Visit"
    case .virtualMeeting: return "Virtual Meeting"
    case .camp: return "Camp"
    case .showcase: return "Showcase"
    case .tweet: return "Tweet"
    case .directMessage: return "Direct Message"
    case .unknown: return "Unknown"
    }
  }

  var iconName: String {
    switch self {
    case .email: return "envelope.fill"
    case .phoneCall: return "phone.fill"
    case .text: return "bubble.left.fill"
    case .inPersonVisit: return "person.2.fill"
    case .virtualMeeting: return "video.fill"
    case .camp: return "figure.run"
    case .showcase: return "star.fill"
    case .tweet: return "bubble.left.fill"
    case .directMessage: return "paperplane.fill"
    case .unknown: return "questionmark.circle.fill"
    }
  }

  var tintColor: Color {
    switch self {
    case .email:          return Color.Brand.blue600
    case .phoneCall:      return Color.Brand.purple600
    case .text:           return Color.Brand.emerald600
    case .inPersonVisit:  return Color.Brand.orange600
    case .virtualMeeting: return Color.Brand.indigo600
    case .camp:           return Color.Brand.orange600
    case .showcase:       return Color.Brand.purple500
    case .tweet:          return Color.Brand.blue500
    case .directMessage:  return Color.Brand.purple600
    case .unknown:        return Color.Brand.slate500
    }
  }

  /// All interaction type badges use blue to maintain visual consistency.
  /// Distinguishing 10 interaction types by color would create excessive visual noise;
  /// the type label and icon carry semantic meaning instead.
  var badgeColor: BadgeColor { .blue }
}
