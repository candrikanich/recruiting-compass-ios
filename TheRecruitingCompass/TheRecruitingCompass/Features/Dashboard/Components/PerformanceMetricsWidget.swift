import SwiftUI

struct PerformanceMetricsWidget: View {
  /// Sorted once at init rather than re-sorted on every body evaluation.
  private let recentMetrics: [PerformanceMetric]

  @State private var isShowingAll = false

  /// A full 3×2 / 2×3 grid before "Show more".
  private static let collapsedCount = 6
  private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

  init(metrics: [PerformanceMetric]) {
    self.recentMetrics = metrics.sorted(by: { $0.recordedDate > $1.recordedDate })
  }

  private var visibleMetrics: [PerformanceMetric] {
    isShowingAll ? recentMetrics : Array(recentMetrics.prefix(Self.collapsedCount))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Performance Metrics")
        .font(.brand(.headline))
        .accessibilityAddTraits(.isHeader)

      Divider()

      if recentMetrics.isEmpty {
        Text("No performance metrics recorded")
          .font(.brand(.caption))
          .foregroundStyle(Color.secondaryText)
          .padding(.vertical)
      } else {
        LazyVGrid(columns: columns, spacing: 12) {
          ForEach(visibleMetrics) { metric in
            MetricTile(metric: metric)
          }
        }

        if recentMetrics.count > Self.collapsedCount {
          Button(action: { isShowingAll.toggle() }) {
            HStack(spacing: 4) {
              Text(isShowingAll
                ? String(localized: "Show less")
                : String(localized: "Show \(recentMetrics.count - Self.collapsedCount) more"))
                .font(.brand(.caption))
              Image(systemName: isShowingAll ? "chevron.up" : "chevron.down")
                .font(.brand(.caption))
                .accessibilityHidden(true)
            }
            .foregroundStyle(Color.accentPrimary)
          }
          .accessibilityLabel(String(localized: isShowingAll
            ? "Show fewer metrics"
            : "Show all \(recentMetrics.count) metrics"))
          .accessibilityHint(isShowingAll
            ? "Collapses the grid to show only the most recent metrics"
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
