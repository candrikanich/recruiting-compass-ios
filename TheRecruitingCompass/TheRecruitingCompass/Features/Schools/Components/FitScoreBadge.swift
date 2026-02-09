import SwiftUI

struct FitScoreBadge: View {
  let score: Double?

  private var displayScore: Int {
    Int(score ?? 0)
  }

  private var color: Color {
    guard let score = score else { return .gray }
    if score >= 70 {
      return .green
    } else if score >= 50 {
      return .orange
    } else {
      return .red
    }
  }

  var body: some View {
    if let score = score {
      BadgeView(
        text: "Fit: \(displayScore)",
        color: color,
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
