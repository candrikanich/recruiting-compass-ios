import SwiftUI

struct TimelineStatPills: View {
  let statusScore: Int
  let statusLabel: StatusLabel?
  let taskCompleted: Int
  let taskTotal: Int
  let milestonesCompleted: Int
  let milestonesTotal: Int

  private var taskPercent: Int {
    guard taskTotal > 0 else { return 0 }
    return Int(round(Double(taskCompleted) / Double(taskTotal) * 100))
  }

  private var statusColor: Color {
    guard let label = statusLabel else { return .secondary }
    switch label {
    case .onTrack: return .successGreen
    case .slightlyBehind: return Color(hex: "F59E0B")
    case .atRisk: return .errorRed
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      statCard(
        icon: "gauge.with.dots.needle.bottom.50percent",
        label: String(localized: "Status"),
        value: "\(statusScore)/100",
        accent: statusColor,
        progress: Double(statusScore),
        total: 100,
        accessibility: String(localized: "Status score \(statusScore) out of 100")
      )

      statCard(
        icon: "checklist",
        label: String(localized: "Tasks"),
        value: "\(taskCompleted)/\(taskTotal)",
        accent: Color.accentBlue,
        progress: Double(taskCompleted),
        total: Double(taskTotal),
        accessibility: String(localized: "Tasks \(taskCompleted) of \(taskTotal) complete, \(taskPercent) percent")
      )

      statCard(
        icon: "flag.checkered",
        label: String(localized: "Milestones"),
        value: "\(milestonesCompleted)/\(milestonesTotal)",
        accent: Color.amberGold,
        progress: Double(milestonesCompleted),
        total: Double(milestonesTotal),
        accessibility: String(localized: "Milestones \(milestonesCompleted) of \(milestonesTotal) complete")
      )
    }
  }

  private func statCard(
    icon: String,
    label: String,
    value: String,
    accent: Color,
    progress: Double,
    total: Double,
    accessibility: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 5) {
        Image(systemName: icon)
          .font(.caption)
          .foregroundStyle(accent)
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Text(value)
        .font(.title3.weight(.bold))
        .foregroundStyle(.primary)
        .contentTransition(.numericText())

      ProgressView(value: min(progress, total), total: max(1, total))
        .tint(accent)
        .scaleEffect(x: 1, y: 0.8, anchor: .center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibility)
  }
}

#Preview {
  TimelineStatPills(
    statusScore: 72,
    statusLabel: .onTrack,
    taskCompleted: 14,
    taskTotal: 28,
    milestonesCompleted: 3,
    milestonesTotal: 4
  )
  .padding()
}
