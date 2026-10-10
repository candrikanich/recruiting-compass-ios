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
  case game
  case unofficialVisit = "unofficial_visit"
  case officialVisit = "official_visit"
  case other
  case unknown

  /// Raw value safe to send to the server; nil for the decode-only `unknown` fallback so the key is omitted.
  var serverValue: String? { self == .unknown ? nil : rawValue }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = InteractionType(rawValue: rawValue) ?? .unknown
  }

  /// User-selectable types. Excludes `unknown` — it's a decode-only fallback
  /// for values absent from the DB `interaction_type` enum, not a real choice.
  static var selectableCases: [InteractionType] {
    allCases.filter { $0 != .unknown }
  }

  var displayName: String {
    switch self {
    case .email: return String(localized: "Email")
    case .phoneCall: return String(localized: "Phone Call")
    case .text: return String(localized: "Text")
    case .inPersonVisit: return String(localized: "In-Person Visit")
    case .virtualMeeting: return String(localized: "Virtual Meeting")
    case .camp: return String(localized: "Camp")
    case .showcase: return String(localized: "Showcase")
    case .tweet: return String(localized: "Tweet")
    case .directMessage: return String(localized: "Direct Message")
    case .game: return String(localized: "Game")
    case .unofficialVisit: return String(localized: "Unofficial Visit")
    case .officialVisit: return String(localized: "Official Visit")
    case .other: return String(localized: "Other")
    case .unknown: return String(localized: "Unknown")
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
    case .game: return "sportscourt.fill"
    case .unofficialVisit: return "building.columns.fill"
    case .officialVisit: return "checkmark.seal.fill"
    case .other: return "ellipsis.circle.fill"
    case .unknown: return "questionmark.circle.fill"
    }
  }

  var tintColor: Color {
    switch self {
    case .email:          return Color.Category.forest
    case .phoneCall:      return Color.Category.gold
    case .text:           return Color.Category.clay
    case .inPersonVisit:  return Color.Category.slate
    case .virtualMeeting: return Color.Category.forest
    case .camp:           return Color.Category.gold
    case .showcase:       return Color.Category.clay
    case .tweet:          return Color.Category.slate
    case .directMessage:  return Color.Category.forest
    case .game:           return Color.Category.gold
    case .unofficialVisit: return Color.Category.clay
    case .officialVisit:  return Color.Category.forest
    case .other:          return Color.Brand.slate500
    case .unknown:        return Color.Brand.slate500
    }
  }

  /// All interaction type badges use blue to maintain visual consistency.
  /// Distinguishing 10 interaction types by color would create excessive visual noise;
  /// the type label and icon carry semantic meaning instead.
  var badgeColor: BadgeColor { .blue }
}
