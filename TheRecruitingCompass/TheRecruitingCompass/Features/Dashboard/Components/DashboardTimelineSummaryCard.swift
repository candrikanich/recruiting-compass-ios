import SwiftUI

/// Compact timeline summary shown at the top of the dashboard: current phase,
/// status score, and the top-priority pending task. Mirrors the web dashboard's
/// `DashboardTimelineCard.vue`. Tapping "View timeline" drills into More → Timeline.
struct DashboardTimelineSummaryCard: View {
  let phase: TimelinePhase
  let statusScore: Int
  /// Status-dot color, from the server's `label`/`color` (via `StatusScore.color`).
  /// The card no longer re-thresholds the raw score locally.
  let statusColor: Color
  let taskTitle: String?
  let taskWhyItMatters: String?
  let onViewTimeline: () -> Void

  /// Phase badge tint, matching web's per-phase badge colors.
  private var badgeColor: Color {
    switch phase {
    case .freshman: return .successGreen
    case .sophomore: return .accentBlue
    case .junior: return .purple
    case .senior: return Color(hex: "F59E0B")
    case .committed: return .successGreen
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Text(phase.displayLabel)
          .font(.caption.weight(.semibold))
          .foregroundStyle(badgeColor)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(badgeColor.opacity(0.15))
          .clipShape(Capsule())

        HStack(spacing: 6) {
          Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
          (Text("\(statusScore)").fontWeight(.bold)
            + Text("/100").foregroundColor(.secondary))
            .font(.headline)
            .monospacedDigit()
        }

        Spacer(minLength: 0)
      }

      taskSection

      Button(action: onViewTimeline) {
        HStack(spacing: 4) {
          Text("View timeline")
          Image(systemName: "arrow.right")
            .accessibilityHidden(true)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color.accentBlue)
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityText)
    .accessibilityHint("Opens your recruiting timeline")
  }

  @ViewBuilder
  private var taskSection: some View {
    if let taskTitle {
      VStack(alignment: .leading, spacing: 2) {
        Text(taskTitle)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)
          .lineLimit(1)
        if let taskWhyItMatters {
          Text(taskWhyItMatters)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      Text("No pending priorities")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var accessibilityText: String {
    let base = String(localized: "\(phase.displayLabel), status score \(statusScore) out of 100")
    if let taskTitle {
      return String(localized: "\(base). Top priority: \(taskTitle)")
    }
    return String(localized: "\(base). No pending priorities")
  }
}

#Preview {
  VStack(spacing: 16) {
    DashboardTimelineSummaryCard(
      phase: .junior,
      statusScore: 20,
      statusColor: .errorRed,
      taskTitle: "Take Official SAT or ACT",
      taskWhyItMatters: "Official test scores are required for college eligibility.",
      onViewTimeline: {}
    )
    DashboardTimelineSummaryCard(
      phase: .senior,
      statusScore: 88,
      statusColor: .successGreen,
      taskTitle: nil,
      taskWhyItMatters: nil,
      onViewTimeline: {}
    )
  }
  .padding()
}
