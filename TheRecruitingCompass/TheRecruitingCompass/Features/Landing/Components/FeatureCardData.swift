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
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    ),
    FeatureCardData(
      icon: "bubble.right.fill",
      title: "Log Interactions",
      description: "Keep track of every conversation with coaches"
    ),
    FeatureCardData(
      icon: "chart.bar.fill",
      title: "Monitor Progress",
      description: "Visualize your recruiting journey with insights"
    )
  ]
}
