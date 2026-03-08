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
          value: statistics.totalStorageMB > 0 ? String(format: "%.1f MB", statistics.totalStorageMB) : "Phase 5",
          color: .orange
        )
      }
      .padding(.horizontal)
    }
    .scrollIndicators(.hidden)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Document statistics: \(statistics.total) total, \(statistics.shared) shared")
  }
}

private struct DocumentStatCard: View {
  let label: String
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
    .frame(width: 140, height: 80)
    .padding(12)
    .background(Color(.systemBackground))
    .clipShape(.rect(cornerRadius: 12))
    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
  }
}
