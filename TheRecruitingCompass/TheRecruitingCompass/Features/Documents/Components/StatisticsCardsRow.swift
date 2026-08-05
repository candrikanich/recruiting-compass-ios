import SwiftUI

struct DocumentStatisticsCardsRow: View {
  let statistics: DocumentStatistics

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 12) {
        DocumentStatCard(
          label: "Total Documents",
          value: "\(statistics.total)",
          color: .blue
        )
        DocumentStatCard(
          label: "Shared Documents",
          value: "\(statistics.shared)",
          color: .green
        )
        DocumentStatCard(
          label: "Most Common Type",
          value: statistics.mostCommonType,
          color: .purple
        )
        DocumentStatCard(
          label: "Total Storage",
          value: statistics.totalStorageMB > 0
            ? "\(statistics.totalStorageMB.formatted(.number.precision(.fractionLength(1)))) MB"
            : "Phase 5",
          color: .orange
        )
      }
      .padding(.horizontal)
    }
    .scrollIndicators(.hidden)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(String(localized: "Document statistics: \(statistics.total) total, \(statistics.shared) shared"))
  }
}

private struct DocumentStatCard: View {
  let label: LocalizedStringKey
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title2)
        .bold()
        .foregroundStyle(color)
    }
    .frame(minWidth: 140, minHeight: 80)
    .padding(12)
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }
}
