import SwiftUI

struct MetricHistoryCard: View {
  let metric: PerformanceMetric
  let onEdit: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(metric.displayName)
            .font(.headline)
          Text(metric.formattedDate)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        HStack(spacing: 8) {
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
    .accessibilityLabel("\(metric.displayName), \(metric.formattedValue), recorded \(metric.formattedDate)")
  }
}
