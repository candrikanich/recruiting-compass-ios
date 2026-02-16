import Foundation

struct ActivityEvent: Identifiable, Sendable {
  let id: String
  let type: ActivityEventType
  let timestamp: Date
  let title: String
  let description: String
  let icon: String
  let entityType: String?
  let entityId: String?
  let entityName: String?
  let isClickable: Bool
  let clickUrl: String?
}

enum ActivityEventType: String, CaseIterable, Sendable {
  case interaction
  case schoolStatusChange = "school_status_change"
  case documentUpload = "document_upload"

  var label: String {
    switch self {
    case .interaction: return "Interactions"
    case .schoolStatusChange: return "School Status Changes"
    case .documentUpload: return "Documents"
    }
  }
}

enum ActivityDateRange: String, CaseIterable, Sendable {
  case all
  case week
  case month
  case quarter

  var label: String {
    switch self {
    case .all: return "All Time"
    case .week: return "Last 7 Days"
    case .month: return "Last 30 Days"
    case .quarter: return "Last 90 Days"
    }
  }

  var daysAgo: Int? {
    switch self {
    case .all: return nil
    case .week: return 7
    case .month: return 30
    case .quarter: return 90
    }
  }
}

enum ActivityIcon {
  static let interactionIcons: [String: String] = [
    "email": "envelope.fill",
    "phone_call": "phone.fill",
    "text": "bubble.left.fill",
    "in_person_visit": "person.2.fill",
    "virtual_meeting": "video.fill",
    "camp": "figure.run",
    "showcase": "star.fill",
    "tweet": "bubble.left.fill",
    "dm": "paperplane.fill"
  ]

  static let defaultInteraction = "pencil.line"
  static let schoolStatus = "mappin.circle.fill"
  static let document = "doc.fill"

  static func forInteractionType(_ type: String) -> String {
    interactionIcons[type] ?? defaultInteraction
  }
}
