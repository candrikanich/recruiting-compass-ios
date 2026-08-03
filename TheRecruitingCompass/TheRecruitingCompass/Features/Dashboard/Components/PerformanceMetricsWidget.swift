import SwiftUI

struct PerformanceMetricsWidget: View {
  /// Sorted once at init rather than re-sorted on every body evaluation.
  private let recentMetrics: [PerformanceMetric]

  @State private var isShowingAll = false

  init(metrics: [PerformanceMetric]) {
    self.recentMetrics = metrics.sorted(by: { $0.recordedDate > $1.recordedDate })
  }

  private var visibleMetrics: [PerformanceMetric] {
    isShowingAll ? recentMetrics : Array(recentMetrics.prefix(4))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Performance Metrics")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Divider()

      if recentMetrics.isEmpty {
        Text("No performance metrics recorded")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
          .padding(.vertical)
      } else {
        VStack(spacing: 12) {
          ForEach(visibleMetrics) { metric in
            MetricRow(metric: metric)
          }
        }

        if recentMetrics.count > 4 {
          Button(action: { isShowingAll.toggle() }) {
            HStack(spacing: 4) {
              Text(isShowingAll
                ? "Show less"
                : "Show \(recentMetrics.count - 4) more metrics")
                .font(.caption)
              Image(systemName: isShowingAll ? "chevron.up" : "chevron.down")
                .font(.caption)
                .accessibilityHidden(true)
            }
            .foregroundStyle(Color.accentBlue)
          }
          .accessibilityLabel(isShowingAll
            ? "Show fewer metrics"
            : "Show all \(recentMetrics.count) metrics")
          .accessibilityHint(isShowingAll
            ? "Collapses the list to show only 4 metrics"
            : "Expands the list to show all metrics")
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }
}

struct MetricRow: View {
  let metric: PerformanceMetric

  private var dateFormatted: String {
    metric.formattedDate
  }

  private var metricIcon: String {
    switch metric.metricType {
    case .velocity, .exitVelo: return "flame"
    case .sixtyTime: return "timer"
    case .popTime: return "stopwatch"
    case .battingAvg: return "baseball"
    case .era: return "chart.bar"
    case .strikeouts: return "figure.strengthtraining.traditional"
    case .other: return "chart.bar"
    }
  }

  private var formattedValue: String {
    metric.formattedValue
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: metricIcon)
        .font(.title3)
        .foregroundStyle(Color.primaryGreen)
        .frame(width: 32)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(metric.displayName)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(formattedValue)
          .font(.body)
          .foregroundStyle(Color.darkSlate)

        Text(dateFormatted)
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
      }

      Spacer()
    }
    .padding(12)
    .frame(minHeight: 44)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(metric.displayName): \(formattedValue)")
    .accessibilityValue("Recorded \(dateFormatted)")
  }
}

#Preview {
  PerformanceMetricsWidget(
    metrics: [
      PerformanceMetric(
        id: "1",
        userId: "user-1",
        metricType: .sixtyTime,
        value: 4.5,
        unit: "sec",
        recordedDate: .now,
        eventId: nil,
        verified: false,
        notes: nil,
        createdAt: .now,
        updatedAt: .now
      ),
      PerformanceMetric(
        id: "2",
        userId: "user-1",
        metricType: .velocity,
        value: 85.0,
        unit: "mph",
        recordedDate: Date.now.addingTimeInterval(-86400 * 15),
        eventId: nil,
        verified: true,
        notes: nil,
        createdAt: .now,
        updatedAt: .now
      ),
      PerformanceMetric(
        id: "3",
        userId: "user-1",
        metricType: .exitVelo,
        value: 92.5,
        unit: "mph",
        recordedDate: Date.now.addingTimeInterval(-86400 * 20),
        eventId: nil,
        verified: false,
        notes: nil,
        createdAt: .now,
        updatedAt: .now
      )
    ]
  )
  .padding()
}
