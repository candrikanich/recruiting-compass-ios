import SwiftUI

/// Communication analytics folded onto the coach detail screen (parity with the
/// web coach page): a compact metrics table, a cross-coach ranking line, and
/// insights. Replaces the former standalone analytics screen.
struct CoachMetricsSection: View {
  let metrics: CoachMetrics
  let comparison: CoachComparison?
  let insights: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Communication Analytics")

      if metrics.totalInteractions == 0 {
        Text("No analytics yet — log an interaction to start.")
          .font(.body)
          .foregroundStyle(.secondary)
          .italic()
          .padding(.vertical, 8)
      } else {
        metricsTable
        if let comparison, comparison.totalCoaches >= 2 {
          rankingLine(comparison)
        }
        if !insights.isEmpty {
          insightsList
        }
      }
    }
  }

  private var metricsTable: some View {
    VStack(spacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
        HStack {
          Text(row.label)
            .font(.subheadline)
            .foregroundStyle(Color.secondaryText)
          Spacer()
          Text(row.value)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.label): \(row.value)")

        if index != rows.count - 1 {
          Divider().accessibilityHidden(true)
        }
      }
    }
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  @ViewBuilder
  private func rankingLine(_ comparison: CoachComparison) -> some View {
    let above = comparison.coach.responseRate >= comparison.schoolAverageResponseRate
    HStack(spacing: 8) {
      Text("Ranks #\(comparison.rank) of \(comparison.totalCoaches) coaches by response rate")
        .font(.footnote)
        .foregroundStyle(.primary)
      Text(above ? "Above avg (\(comparison.schoolAverageResponseRate)%)" : "Below avg (\(comparison.schoolAverageResponseRate)%)")
        .font(.caption.weight(.medium))
        .foregroundStyle((above ? BadgeColor.emerald : BadgeColor.orange).foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((above ? BadgeColor.emerald : BadgeColor.orange).backgroundColor)
        .clipShape(Capsule())
    }
    .accessibilityElement(children: .combine)
  }

  private var insightsList: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "lightbulb.fill")
            .font(.caption)
            .foregroundStyle(BadgeColor.blue.foregroundColor)
            .accessibilityHidden(true)
          Text(insight)
            .font(.footnote)
            .foregroundStyle(.primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BadgeColor.blue.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  private struct Row {
    let label: String
    let value: String
  }

  private var rows: [Row] {
    [
      Row(label: String(localized: "Total interactions"), value: "\(metrics.totalInteractions)"),
      Row(label: String(localized: "Sent / received"), value: "\(metrics.outboundCount) / \(metrics.inboundCount)"),
      Row(label: String(localized: "Response rate"), value: "\(metrics.responseRate)%"),
      Row(
        label: String(localized: "Avg response time"),
        value: metrics.averageResponseTime > 0 ? "\(formatHours(metrics.averageResponseTime))h" : "—"
      ),
      Row(
        label: String(localized: "Days since contact"),
        value: metrics.daysSinceContact >= 0 ? "\(metrics.daysSinceContact)" : String(localized: "N/A")
      ),
      Row(label: String(localized: "Preferred method"), value: metrics.preferredMethod)
    ]
  }

  private func formatHours(_ hours: Double) -> String {
    hours == hours.rounded() ? "\(Int(hours))" : "\(hours)"
  }
}

#Preview {
  CoachMetricsSection(
    metrics: CoachMetrics(
      totalInteractions: 12,
      responseRate: 67,
      averageResponseTime: 8.5,
      lastContactDate: .now,
      daysSinceContact: 3,
      preferredMethod: "Email",
      outboundCount: 8,
      inboundCount: 4
    ),
    comparison: CoachComparison(
      coach: CoachMetrics(
        totalInteractions: 12, responseRate: 67, averageResponseTime: 8.5,
        lastContactDate: .now, daysSinceContact: 3, preferredMethod: "Email",
        outboundCount: 8, inboundCount: 4
      ),
      schoolAverageResponseRate: 50,
      rank: 2,
      totalCoaches: 6
    ),
    insights: ["Quick responder - average 8.5 hours", "Prefers responding via Email"]
  )
  .padding()
}
