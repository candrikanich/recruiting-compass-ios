import SwiftUI

struct BadgeView: View {
  let text: String
  let color: Color
  let accessibilityLabel: String?

  init(text: String, color: Color, accessibilityLabel: String? = nil) {
    self.text = text
    self.color = color
    self.accessibilityLabel = accessibilityLabel
  }

  var body: some View {
    Text(text)
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color.opacity(0.15))
      .foregroundColor(color)
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .accessibilityLabel(accessibilityLabel ?? text)
  }
}

#Preview {
  VStack(spacing: 12) {
    BadgeView(text: "D1", color: .blue)
    BadgeView(text: "Interested", color: .gray)
    BadgeView(text: "Fit: 85", color: .green)
    BadgeView(text: "Tier A", color: .purple, accessibilityLabel: "Priority tier A")
  }
  .padding()
}
