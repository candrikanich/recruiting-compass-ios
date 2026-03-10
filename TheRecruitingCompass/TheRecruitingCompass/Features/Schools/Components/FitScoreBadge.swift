import SwiftUI

struct FitScoreBadge: View {
  let score: Double?

  private var displayScore: Int { Int(score ?? 0) }

  private var badgeColor: BadgeColor {
    guard let score else { return .slate }
    if score >= 70 { return .emerald }
    if score >= 50 { return .orange }
    return .red
  }

  var body: some View {
    if score != nil {
      BadgeView(
        text: "Fit: \(displayScore)",
        color: badgeColor,
        accessibilityLabel: "Fit score \(displayScore) out of 100"
      )
    }
  }
}

#Preview {
  VStack(spacing: 12) {
    FitScoreBadge(score: 85)
    FitScoreBadge(score: 65)
    FitScoreBadge(score: 45)
    FitScoreBadge(score: nil)
  }
  .padding()
}
