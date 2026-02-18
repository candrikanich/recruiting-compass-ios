import SwiftUI

struct EventTypeBadge: View {
  let type: String

  private var eventType: EventType? { EventType(rawValue: type) }

  var body: some View {
    BadgeLabel(text: eventType?.displayName ?? type, color: badgeColor)
  }

  private var badgeColor: Color {
    switch eventType {
    case .showcase: return .purple
    case .camp: return .green
    case .officialVisit: return .blue
    case .unofficialVisit: return .cyan
    case .game: return .orange
    case nil: return .gray
    }
  }
}

struct EventStatusBadge: View {
  let registered: Bool
  let attended: Bool

  var body: some View {
    BadgeLabel(text: label, color: color)
  }

  private var label: String {
    if attended { return "Attended" }
    if registered { return "Registered" }
    return "Not Registered"
  }

  private var color: Color {
    if attended { return .green }
    if registered { return .blue }
    return .gray
  }
}

// MARK: - Shared Badge Style

private struct BadgeLabel: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(color.opacity(0.15))
      .foregroundStyle(color)
      .clipShape(Capsule())
  }
}
