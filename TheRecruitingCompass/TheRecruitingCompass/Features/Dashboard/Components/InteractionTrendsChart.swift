import SwiftUI
import Charts

struct InteractionTrendsChart: View {
  let trends: [InteractionTrend]

  @Environment(\.sizeCategory) private var sizeCategory

  private var totalInteractions: Int {
    trends.map(\.count).reduce(0, +)
  }

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 40 : 32
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Interaction Trends")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Divider()

      if trends.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "chart.bar.xaxis")
            .font(.system(size: iconSize))
            .foregroundColor(Color.secondaryText)
            .accessibilityHidden(true)

          Text("No interaction data yet")
            .font(.body)
            .foregroundColor(Color.secondaryText)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
      } else {
        Chart(trends) { trend in
          BarMark(
            x: .value("Date", trend.dateFormatted, unit: .day),
            y: .value("Count", trend.count)
          )
          .foregroundStyle(Color.primaryGreen.gradient)
        }
        .frame(height: 200)
        .chartXAxis {
          AxisMarks(values: .stride(by: .day)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          }
        }
        .chartYAxis {
          AxisMarks(position: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bar chart showing interaction trends over \(trends.count) days")
        .accessibilityValue("\(totalInteractions) total interactions, latest: \(trends.last?.count ?? 0)")

        Text("\(totalInteractions) total interactions over \(trends.count) days")
          .font(.caption)
          .foregroundColor(Color.secondaryText)
          .accessibilityHidden(true)
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

#Preview {
  InteractionTrendsChart(
    trends: [
      InteractionTrend(id: "1", date: "2026-02-01T12:00:00Z", count: 3),
      InteractionTrend(id: "2", date: "2026-02-02T12:00:00Z", count: 5),
      InteractionTrend(id: "3", date: "2026-02-03T12:00:00Z", count: 2),
      InteractionTrend(id: "4", date: "2026-02-04T12:00:00Z", count: 7),
      InteractionTrend(id: "5", date: "2026-02-05T12:00:00Z", count: 4)
    ]
  )
  .padding()
}
