import SwiftUI

struct TrendIndicator: View {
  let trend: MetricTrend.TrendDirection

  var body: some View {
    Label(trend.label, systemImage: trend.systemImage)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(backgroundColor)
      .foregroundStyle(foregroundColor)
      .clipShape(Capsule())
      .accessibilityLabel("Trend: \(trend.label)")
  }

  private var backgroundColor: Color {
    switch trend {
    case .improving: return Color.successGreen.opacity(0.15)
    case .declining: return Color.errorRed.opacity(0.15)
    case .stable: return Color(.systemGray5)
    }
  }

  private var foregroundColor: Color {
    switch trend {
    case .improving: return Color.successGreen
    case .declining: return Color.errorRed
    case .stable: return Color(.systemGray)
    }
  }
}
