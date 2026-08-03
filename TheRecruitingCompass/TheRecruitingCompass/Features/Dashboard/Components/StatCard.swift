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

  @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 24

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
          .foregroundStyle(.white)

        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.white)
        }

        if let description {
          Text(description)
            .font(.caption)
            .foregroundStyle(.white)
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
    gradientColors: [Color.Brand.blue600, Color.Brand.blue700],
    isEnabled: true,
    destination: .coaches
  )
  .padding()
}
