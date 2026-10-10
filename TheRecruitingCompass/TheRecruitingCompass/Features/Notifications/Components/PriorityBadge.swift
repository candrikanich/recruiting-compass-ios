import SwiftUI

struct PriorityBadge: View, Equatable {
  let priority: NotificationPriority

  private var textColor: Color {
    switch priority {
    case .high: return Palette.highText
    case .normal: return Palette.normalText
    case .low, .unknown: return Palette.mutedText
    }
  }

  private var backgroundColor: Color {
    switch priority {
    case .high: return Palette.highBackground
    case .normal: return Palette.normalBackground
    case .low, .unknown: return Palette.mutedBackground
    }
  }

  var body: some View {
    Text(priority.label)
      .font(.brand(.caption, weight: .bold))
      .foregroundStyle(textColor)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(backgroundColor)
      .clipShape(.rect(cornerRadius: 4))
  }

  private enum Palette {
    static let highText = Color(hex: "#B91C1C")
    static let normalText = Color(hex: "#254B20")
    static let mutedText = Color(hex: "#57534E")
    static let highBackground = Color(hex: "#FEE2E2")
    static let normalBackground = Color(hex: "#E3EDE0")
    static let mutedBackground = Color(hex: "#F5F5F0")
  }
}
