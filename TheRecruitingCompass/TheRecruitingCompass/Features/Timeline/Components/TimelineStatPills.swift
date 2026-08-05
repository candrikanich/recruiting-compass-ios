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
      statusPill
      tasksPill
      milestonesPill
    }
  }

  @ViewBuilder
  private var statusPill: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Status")
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack(spacing: 6) {
        Circle()
          .fill(statusColor)
          .frame(width: 8, height: 8)
        Text("\(statusScore)/100")
          .font(.headline)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Status score \(statusScore) out of 100"))
  }

  @ViewBuilder
  private var tasksPill: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Tasks")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("\(taskCompleted)/\(taskTotal)")
        .font(.headline)
      ProgressView(value: Double(taskCompleted), total: max(1, Double(taskTotal)))
        .tint(Color.accentBlue)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Tasks \(taskCompleted) of \(taskTotal) complete, \(taskPercent) percent"))
  }

  @ViewBuilder
  private var milestonesPill: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Milestones")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("\(milestonesCompleted)/\(milestonesTotal)")
        .font(.headline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Milestones \(milestonesCompleted) of \(milestonesTotal) complete"))
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
