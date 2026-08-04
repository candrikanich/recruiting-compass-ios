import Foundation

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
