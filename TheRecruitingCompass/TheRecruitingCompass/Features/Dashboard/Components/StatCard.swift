import SwiftUI

struct StatCard: View {
  let title: String
  let count: Int
  let subtitle: String?
  let icon: String
  let gradientColors: [Color]
  let isEnabled: Bool

  @Environment(\.sizeCategory) var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory >= .extraLarge ? 36 : 32
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: icon)
          .font(.system(size: iconSize))
          .foregroundColor(.white)
          .accessibilityHidden(true)

        Spacer()
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("\(count)")
          .font(.system(size: 32, weight: .bold))
          .foregroundColor(.white)

        Text(title)
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.9))

        if let subtitle = subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, minHeight: 120)
    .background(
      LinearGradient(
        gradient: Gradient(colors: gradientColors),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    .opacity(isEnabled ? 1.0 : 0.7)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(count)")
    .accessibilityValue(subtitle ?? "")
    .accessibilityAddTraits(isEnabled ? [.isButton] : [])
  }
}

#Preview {
  StatCard(
    title: "Coaches",
    count: 12,
    subtitle: nil,
    icon: "person.2.fill",
    gradientColors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
    isEnabled: false
  )
  .padding()
}
