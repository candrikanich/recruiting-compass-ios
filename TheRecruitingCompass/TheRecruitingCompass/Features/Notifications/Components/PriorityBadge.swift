import SwiftUI

struct PriorityBadge: View {
  let priority: NotificationPriority

  private var textColor: Color {
    switch priority {
    case .high: return Color(hex: "#B91C1C")
    case .normal: return Color(hex: "#1D4ED8")
    case .low: return Color(hex: "#4B5563")
    case .unknown: return Color(hex: "#4B5563")
    }
  }

  private var backgroundColor: Color {
    switch priority {
    case .high: return Color(hex: "#FEE2E2")
    case .normal: return Color(hex: "#DBEAFE")
    case .low: return Color(hex: "#F3F4F6")
    case .unknown: return Color(hex: "#F3F4F6")
    }
  }

  var body: some View {
    Text(priority.label)
      .font(.caption.weight(.bold))
      .foregroundStyle(textColor)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(backgroundColor)
      .clipShape(.rect(cornerRadius: 4))
  }
}
