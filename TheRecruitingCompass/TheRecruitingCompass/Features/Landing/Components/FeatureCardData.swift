import Foundation

struct FeatureCardData: Identifiable {
  let id = UUID()
  let icon: String
  let title: String
  let description: String
}

extension FeatureCardData {
  static let landingFeatures: [FeatureCardData] = [
    FeatureCardData(
      icon: "shield.checkered",
      title: String(localized: "Track Schools"),
      description: String(localized: "Organize and manage your target colleges in one place")
    ),
    FeatureCardData(
      icon: "bubble.right.fill",
      title: String(localized: "Log Interactions"),
      description: String(localized: "Keep track of every conversation with coaches")
    ),
    FeatureCardData(
      icon: "chart.bar.fill",
      title: String(localized: "Monitor Progress"),
      description: String(localized: "Visualize your recruiting journey with insights")
    )
  ]
}
