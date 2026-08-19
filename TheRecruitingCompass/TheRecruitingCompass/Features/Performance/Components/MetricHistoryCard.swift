import SwiftUI

struct MetricHistoryCard: View {
  let metric: PerformanceMetric
  let onEdit: () -> Void
  let onDelete: () -> Void
  let onTogglePrimary: () -> Void

  private var primaryButtonLabel: String {
    metric.isPrimary
      ? String(localized: "Clear headline metric")
      : String(localized: "Set as headline metric")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(metric.displayName)
              .font(.headline)
            if metric.isPrimary {
              Text("Headline")
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentBlue.opacity(0.12))
                .foregroundStyle(Color.accentBlue)
                .clipShape(Capsule())
            }
          }
          Text(metric.formattedDate)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        HStack(spacing: 8) {
          Button(action: onTogglePrimary) {
            Image(systemName: metric.isPrimary ? "star.fill" : "star")
          }
          .font(.caption)
          .fontWeight(.semibold)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.accentBlue.opacity(metric.isPrimary ? 0.18 : 0.1))
          .foregroundStyle(metric.isPrimary ? Color.accentBlue : Color.secondary)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .accessibilityLabel(primaryButtonLabel)

          Button("Edit", action: onEdit)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentBlue.opacity(0.1))
            .foregroundStyle(Color.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 8))

          Button("Delete", action: onDelete)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.errorRed.opacity(0.1))
            .foregroundStyle(Color.errorRed)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
      }

      HStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Value")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(metric.formattedValue)
            .font(.subheadline)
            .bold()
        }

        if metric.verified {
          VStack(alignment: .leading, spacing: 2) {
            Text("Status")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("Verified", systemImage: "checkmark.seal.fill")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(Color.successGreen)
          }
        }
      }

      if let notes = metric.notes, !notes.isEmpty {
        Divider()
        Text(notes)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      metric.isPrimary
        ? String(localized: "\(metric.displayName), \(metric.formattedValue), headline metric, recorded \(metric.formattedDate)")
        : String(localized: "\(metric.displayName), \(metric.formattedValue), recorded \(metric.formattedDate)")
    )
  }
}
