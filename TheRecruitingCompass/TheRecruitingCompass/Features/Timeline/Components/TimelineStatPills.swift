import SwiftUI

struct TimelineStatPills: View {
  /// `nil` until the family has a coach and a conversation; a new account would otherwise read "at risk".
  let status: Status?
  let taskCompleted: Int
  let taskTotal: Int
  let milestonesCompleted: Int
  let milestonesTotal: Int

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  struct Status: Equatable {
    let score: Int
    let label: StatusLabel?
  }

  enum Card: Hashable {
    case status, tasks, milestones
  }

  /// The cards on screen, in order. The status card exists only when there is a status to show.
  var visibleCards: [Card] {
    (status == nil ? [] : [.status]) + [.tasks, .milestones]
  }

  private var taskPercent: Int {
    guard taskTotal > 0 else { return 0 }
    return Int(round(Double(taskCompleted) / Double(taskTotal) * 100))
  }

  private var statusColor: Color {
    guard let label = status?.label else { return .secondary }
    switch label {
    case .onTrack: return .successGreen
    case .slightlyBehind: return Color(hex: "F59E0B")
    case .atRisk: return .errorRed
    case .unknown: return .secondary
    }
  }

  var body: some View {
    let layout = dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 12))
      : AnyLayout(HStackLayout(spacing: 12))
    layout {
      ForEach(visibleCards, id: \.self) { card in
        switch card {
        case .status: statusCard
        case .tasks: tasksCard
        case .milestones: milestonesCard
        }
      }
    }
  }

  @ViewBuilder
  private var statusCard: some View {
    let statusScore = status?.score ?? 0
    statCard(
      icon: "gauge.with.dots.needle.bottom.50percent",
      label: String(localized: "Status"),
      value: "\(statusScore)/100",
      accent: statusColor,
      progress: Double(statusScore),
      total: 100,
      accessibility: String(localized: "Status score \(statusScore) out of 100")
    )
  }

  @ViewBuilder
  private var tasksCard: some View {
    statCard(
      icon: "checklist",
      label: String(localized: "Tasks"),
      value: "\(taskCompleted)/\(taskTotal)",
      accent: Color.accentPrimary,
      progress: Double(taskCompleted),
      total: Double(taskTotal),
      accessibility: String(localized: "Tasks \(taskCompleted) of \(taskTotal) complete, \(taskPercent) percent")
    )
  }

  @ViewBuilder
  private var milestonesCard: some View {
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
          .font(.brand(.caption))
          .foregroundStyle(accent)
        Text(label)
          .font(.brand(.caption))
          .foregroundStyle(.secondary)
      }

      Text(value)
        .font(.brand(.title3, weight: .bold))
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
    status: .init(score: 72, label: .onTrack),
    taskCompleted: 14,
    taskTotal: 28,
    milestonesCompleted: 3,
    milestonesTotal: 4
  )
  .padding()
}
