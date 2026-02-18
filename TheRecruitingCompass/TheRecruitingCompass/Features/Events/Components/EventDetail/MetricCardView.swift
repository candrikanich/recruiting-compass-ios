import SwiftUI

struct MetricCardView: View {
  private enum Layout {
    static let contentSpacing: CGFloat = 8
    static let valueSpacing: CGFloat = 4
    static let cornerRadius: CGFloat = 12
  }

  let metric: PerformanceMetric

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.contentSpacing) {
      HStack {
        Text(metric.displayName)
          .font(.subheadline)
          .fontWeight(.medium)
        Spacer()
        if metric.verified {
          Image(systemName: "checkmark.seal.fill")
            .foregroundStyle(.green)
            .accessibilityLabel("Verified")
        }
      }

      HStack(alignment: .firstTextBaseline, spacing: Layout.valueSpacing) {
        Text(metric.formattedValue)
          .font(.title2)
          .fontWeight(.bold)
          .foregroundStyle(.primary)
      }

      Text(metric.formattedDate)
        .font(.caption)
        .foregroundStyle(.secondary)

      if let notes = metric.notes, !notes.isEmpty {
        Text(notes)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(metricAccessibilityLabel)
  }

  private var metricAccessibilityLabel: String {
    let verifiedStatus = metric.verified ? "Verified" : "Not verified"
    return "\(metric.displayName), \(metric.formattedValue), \(verifiedStatus)"
  }
}
