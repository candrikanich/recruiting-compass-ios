import SwiftUI

struct StatCard: View {
  let title: String
  let count: Int
  let subtitle: String?
  let description: String?
  let icon: String
  let gradientColors: [Color]
  let isEnabled: Bool
  let destination: DashboardDestination?

  @Environment(\.sizeCategory) var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory >= .extraLarge ? 28 : 24
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: icon)
          .font(.system(size: iconSize))
          .foregroundStyle(.white)
          .padding(8)
          .background(Color.white.opacity(0.25))
          .clipShape(.rect(cornerRadius: 8))
          .accessibilityHidden(true)

        Spacer()
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("\(count)")
          .font(.largeTitle.weight(.bold))
          .foregroundStyle(.white)

        Text(title)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(.white.opacity(0.9))

        if let subtitle = subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
        }

        if let description = description {
          Text(description)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 20)
    .padding(.bottom, 20)
    .frame(maxWidth: .infinity, minHeight: 180)
    .background(
      LinearGradient(
        gradient: Gradient(colors: gradientColors),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .opacity(isEnabled ? 1.0 : 0.7)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(count)")
    .accessibilityValue([subtitle, description].compactMap { $0 }.joined(separator: ". "))
    .accessibilityAddTraits(isEnabled ? [.isButton] : [])
    .accessibilityHint(isEnabled ? "Tap to view \(title.lowercased())" : "")
  }
}

#Preview {
  StatCard(
    title: "Coaches",
    count: 12,
    subtitle: nil,
    description: "View all coaches",
    icon: "person.2",
    gradientColors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
    isEnabled: true,
    destination: .coaches
  )
  .padding()
}
