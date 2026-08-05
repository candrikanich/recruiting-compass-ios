import SwiftUI

struct FeatureCard: View {
  let icon: String
  let title: String
  let description: String
  @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 32

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: iconSize))
        .foregroundStyle(.white)
        .accessibilityHidden(true)

      Text(title)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.white)

      Text(description)
        .font(.subheadline)
        .foregroundStyle(Color.white.opacity(0.85))
        .lineLimit(3)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(20)
    .background(Color.white.opacity(0.1))
    .clipShape(.rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Feature: \(title)"))
    .accessibilityValue(description)
  }
}

#Preview {
  VStack(spacing: 16) {
    ForEach(FeatureCardData.landingFeatures) { feature in
      FeatureCard(
        icon: feature.icon,
        title: feature.title,
        description: feature.description
      )
    }
  }
  .padding()
  .background(LinearGradient.landingBackground)
}
