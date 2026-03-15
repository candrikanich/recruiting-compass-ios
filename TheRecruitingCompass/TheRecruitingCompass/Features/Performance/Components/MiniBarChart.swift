import SwiftUI
import Charts

struct MiniBarChart: View {
  let values: [Double]
  let maxValue: Double

  var body: some View {
    Chart(Array(values.enumerated()), id: \.offset) { index, value in
      BarMark(
        x: .value("Index", index),
        y: .value("Value", value)
      )
      .foregroundStyle(Color.accentBlue)
      .cornerRadius(3)
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: 0...max(maxValue, 1))
    .accessibilityHidden(true)
  }
}
