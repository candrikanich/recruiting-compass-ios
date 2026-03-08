import SwiftUI

struct BadgeView: View {
  let text: String
  let color: Color
  let icon: String?
  let accessibilityLabel: String?

  init(text: String, color: Color, icon: String? = nil, accessibilityLabel: String? = nil) {
    self.text = text
    self.color = color
    self.icon = icon
    self.accessibilityLabel = accessibilityLabel
  }

  var body: some View {
    HStack(spacing: 4) {
      if let icon = icon {
        Image(systemName: icon)
          .font(.caption)
          .accessibilityHidden(true)
      }
      Text(text)
    }
    .font(.caption)
    .fontWeight(.medium)
    .padding(.horizontal, icon != nil ? 12 : 8)
    .padding(.vertical, 6)
    .background(color.opacity(0.2))
    .foregroundStyle(color)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .accessibilityLabel(accessibilityLabel ?? text)
  }
}

#Preview {
  VStack(spacing: 12) {
    BadgeView(text: "D1", color: .blue)
    BadgeView(text: "Email", color: .blue, icon: "envelope.fill")
    BadgeView(text: "Interested", color: .gray)
    BadgeView(text: "Fit: 85", color: .green)
    BadgeView(text: "Tier A", color: .purple, accessibilityLabel: "Priority tier A")
  }
  .padding()
}
