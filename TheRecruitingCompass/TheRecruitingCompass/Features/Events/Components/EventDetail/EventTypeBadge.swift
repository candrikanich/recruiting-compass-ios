import SwiftUI

struct EventTypeBadge: View {
  let type: String

  private var eventType: EventType? { EventType(rawValue: type) }

  var body: some View {
    BadgeLabel(text: eventType?.displayName ?? type, color: badgeColor)
  }

  private var badgeColor: Color {
    switch eventType {
    case .showcase: return Color.Category.gold
    case .camp: return .green
    case .officialVisit: return Color.accentPrimary
    case .unofficialVisit: return Color.Category.clay
    case .game: return .orange
    case nil: return .gray
    }
  }
}
