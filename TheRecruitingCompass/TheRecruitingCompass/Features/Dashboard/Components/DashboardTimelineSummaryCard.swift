import SwiftUI

/// First thing on Home: the favorite school (when there is one), the next one to three steps, and, once there is a
/// coach and a conversation behind it, the status score. Mirrors the web dashboard's `DashboardTimelineCard.vue`.
/// Tapping "Timeline" drills into More → Timeline.
struct DashboardTimelineSummaryCard: View {
  /// `nil` until the phase is known: the freshman default must never pass for the athlete's grade.
  let phase: TimelinePhase?
  /// `nil` hides the score entirely.
  let status: Status?
  let favoriteSchoolName: String?
  let nextSteps: [WhatMattersItem]
  /// A failed phase fetch: say so instead of showing another grade's steps.
  let stepsUnavailable: Bool
  let onViewTimeline: () -> Void

  struct Status: Equatable {
    let score: Int
    /// From the server's `label`/`color` (via `StatusScore.color`); the card never re-thresholds the score.
    let color: Color
  }

  /// Phase badge tint, matching web's per-phase badge colors.
  private func badgeColor(for phase: TimelinePhase) -> Color {
    switch phase {
    case .freshman: return .successGreen
    case .sophomore: return .accentPrimary
    case .junior: return Color.Category.gold
    case .senior: return Color(hex: "F59E0B")
    case .committed: return .successGreen
    case .unknown: return .secondary
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        if let phase {
          phaseBadge(phase)
        }
        if let status {
          statusIndicator(status)
        }
        Spacer(minLength: 8)
        timelineButton
      }

      if let favoriteSchoolName {
        (Text("Your top school: ") + Text(favoriteSchoolName).fontWeight(.semibold))
          .font(.brand(.subheadline))
          .foregroundStyle(.secondary)
      }

      stepsSection
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityText)
    .accessibilityHint("Opens your recruiting timeline")
  }

  private func phaseBadge(_ phase: TimelinePhase) -> some View {
    let color = badgeColor(for: phase)
    return Text(phase.displayLabel)
      .font(.brand(.caption, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(color.opacity(0.15))
      .clipShape(Capsule())
  }

  private func statusIndicator(_ status: Status) -> some View {
    HStack(spacing: 6) {
      Circle()
        .fill(status.color)
        .frame(width: 10, height: 10)
      (Text("\(status.score)").fontWeight(.bold) + Text("/100").foregroundStyle(.secondary))
        .font(.brand(.headline))
        .monospacedDigit()
    }
  }

  @ViewBuilder
  private var timelineButton: some View {
    Button(action: onViewTimeline) {
      HStack(spacing: 3) {
        Text("Timeline")
        Image(systemName: "arrow.right")
          .accessibilityHidden(true)
      }
      .font(.brand(.caption, weight: .semibold))
      .foregroundStyle(Color.accentPrimary)
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("View timeline")
    .fixedSize()
  }

  @ViewBuilder
  private var stepsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Your next steps")
        .font(.brand(.subheadline, weight: .semibold))
      if !nextSteps.isEmpty {
        ForEach(nextSteps) { step in
          VStack(alignment: .leading, spacing: 2) {
            Text(step.title)
              .font(.brand(.subheadline, weight: .medium))
              .foregroundStyle(.primary)
            Text(step.whyItMatters)
              .font(.brand(.caption))
              .foregroundStyle(.secondary)
          }
        }
      } else if stepsUnavailable {
        Text(Self.unavailableMessage)
          .font(.brand(.subheadline))
          .foregroundStyle(.secondary)
      } else {
        Text("No pending priorities")
          .font(.brand(.subheadline))
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  static let unavailableMessage = FirstRunCopy.nextStepsUnavailable

  var accessibilityText: String {
    var parts: [String] = []
    if let phase { parts.append(phase.displayLabel) }
    if let status { parts.append(String(localized: "status score \(status.score) out of 100")) }
    if let favoriteSchoolName { parts.append(String(localized: "Your top school: \(favoriteSchoolName)")) }
    if !nextSteps.isEmpty {
      let titles = nextSteps.map(\.title).formatted()
      parts.append(String(localized: "Next steps: \(titles)"))
    } else if stepsUnavailable {
      parts.append(Self.unavailableMessage)
    } else {
      parts.append(String(localized: "No pending priorities"))
    }
    return parts.joined(separator: ". ")
  }
}

#Preview {
  VStack(spacing: 16) {
    DashboardTimelineSummaryCard(
      phase: .junior,
      status: .init(score: 20, color: .errorRed),
      favoriteSchoolName: "State University",
      nextSteps: [
        WhatMattersItem(
          taskId: "1", title: "Take Official SAT or ACT",
          whyItMatters: "Official test scores are required for college eligibility.",
          category: "academics", priority: 1, isRequired: true
        )
      ],
      stepsUnavailable: false,
      onViewTimeline: {}
    )
    DashboardTimelineSummaryCard(
      phase: nil, status: nil, favoriteSchoolName: nil, nextSteps: [], stepsUnavailable: true, onViewTimeline: {}
    )
  }
  .padding()
}
