import SwiftUI

struct PerformanceMetricsWidget: View {
  let metrics: [PerformanceMetric]

  private var recentMetrics: [PerformanceMetric] {
    metrics.sorted { $0.recordedDate > $1.recordedDate }.prefix(4).map { $0 }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Performance Metrics")
        .font(.headline)

      Divider()

      if recentMetrics.isEmpty {
        Text("No performance metrics recorded")
          .font(.caption)
          .foregroundColor(Color.secondaryText)
          .padding(.vertical)
      } else {
        VStack(spacing: 12) {
          ForEach(recentMetrics) { metric in
            MetricRow(metric: metric)
          }
        }

        if metrics.count > 4 {
          Button("Show \(metrics.count - 4) more metrics") {
          }
          .font(.caption)
          .foregroundColor(Color.accentBlue)
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct MetricRow: View {
  let metric: PerformanceMetric

  private var dateFormatted: String {
    guard let date = ISO8601DateFormatter().date(from: metric.recordedDate) else {
      return metric.recordedDate
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }

  private var metricIcon: String {
    let type = metric.metricType.lowercased()
    if type.contains("40") || type.contains("dash") || type.contains("sprint") {
      return "timer"
    } else if type.contains("gpa") || type.contains("sat") || type.contains("act") {
      return "book"
    } else if type.contains("bench") || type.contains("squat") || type.contains("press") {
      return "figure.strengthtraining.traditional"
    } else if type.contains("vertical") || type.contains("jump") {
      return "arrow.up"
    } else {
      return "chart.bar"
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: metricIcon)
        .font(.title3)
        .foregroundColor(Color.primaryGreen)
        .frame(width: 32)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(metric.displayName)
          .font(.subheadline)
          .fontWeight(.semibold)

        HStack {
          Text(String(format: "%.2f", metric.value))
            .font(.body)
            .foregroundColor(Color.darkSlate)

          if let unit = metric.unit {
            Text(unit)
              .font(.caption)
              .foregroundColor(Color.secondaryText)
          }
        }

        Text(dateFormatted)
          .font(.caption)
          .foregroundColor(Color.secondaryText)
      }

      Spacer()
    }
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(metric.displayName): \(metric.value) \(metric.unit ?? "")")
    .accessibilityValue("Recorded \(dateFormatted)")
  }
}

#Preview {
  PerformanceMetricsWidget(
    metrics: [
      PerformanceMetric(
        id: "1",
        metricType: "40_yard_dash",
        value: 4.5,
        unit: "seconds",
        recordedDate: "2026-02-01T12:00:00Z",
        userId: "user-1",
        createdAt: "2026-02-01T12:00:00Z"
      ),
      PerformanceMetric(
        id: "2",
        metricType: "gpa",
        value: 3.8,
        unit: nil,
        recordedDate: "2026-01-15T12:00:00Z",
        userId: "user-1",
        createdAt: "2026-01-15T12:00:00Z"
      ),
      PerformanceMetric(
        id: "3",
        metricType: "bench_press",
        value: 225,
        unit: "lbs",
        recordedDate: "2026-01-10T12:00:00Z",
        userId: "user-1",
        createdAt: "2026-01-10T12:00:00Z"
      )
    ]
  )
  .padding()
}
