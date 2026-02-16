import SwiftUI

struct MiniBarChart: View {
  let values: [Double]
  let maxValue: Double

  var body: some View {
    GeometryReader { geometry in
      HStack(alignment: .bottom, spacing: barSpacing(totalWidth: geometry.size.width)) {
        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentBlue)
            .frame(height: barHeight(value: value, totalHeight: geometry.size.height))
        }
      }
    }
    .accessibilityHidden(true)
  }

  private func barHeight(value: Double, totalHeight: CGFloat) -> CGFloat {
    guard maxValue > 0 else { return 0 }
    return max(4, CGFloat(value / maxValue) * totalHeight)
  }

  private func barSpacing(totalWidth: CGFloat) -> CGFloat {
    guard values.count > 1 else { return 0 }
    let barCount = CGFloat(values.count)
    let totalSpacing = totalWidth * 0.2
    return totalSpacing / (barCount - 1)
  }
}
