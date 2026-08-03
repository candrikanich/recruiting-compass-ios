import SwiftUI

struct BadgeView: View {
  let text: String
  let color: BadgeColor
  let icon: String?
  let accessibilityLabel: String?

  init(text: String, color: BadgeColor, icon: String? = nil, accessibilityLabel: String? = nil) {
    self.text = text
    self.color = color
    self.icon = icon
    self.accessibilityLabel = accessibilityLabel
  }

  var body: some View {
    HStack(spacing: 4) {
      if let icon {
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
    .background(color.backgroundColor)
    .foregroundStyle(color.foregroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .accessibilityLabel(accessibilityLabel ?? text)
  }
}

#Preview {
  VStack(spacing: 12) {
    BadgeView(text: "D1", color: .blue)
    BadgeView(text: "Email", color: .blue, icon: "envelope.fill")
    BadgeView(text: "Interested", color: .slate)
    BadgeView(text: "Fit: 85", color: .emerald)
    BadgeView(text: "Tier A", color: .red, accessibilityLabel: "Priority tier A")
  }
  .padding()
}
