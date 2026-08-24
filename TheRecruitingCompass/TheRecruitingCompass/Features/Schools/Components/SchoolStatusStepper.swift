import SwiftUI

/// Horizontal progress stepper over the canonical recruiting funnel
/// (`SchoolStatus.pipeline`). Tapping a stage sets the school's status. The
/// `not_pursuing` off-ramp is handled separately (it is not on the linear
/// track) via a secondary action below the track.
///
/// See planning/2026-08-21-school-status-pipeline-spec.md.
struct SchoolStatusStepper: View {
  let currentStatus: SchoolStatus
  let isUpdating: Bool
  let onSelect: (SchoolStatus) async -> Void

  private var isOffRamp: Bool { currentStatus == .notPursuing }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      track
        .opacity(isOffRamp ? 0.35 : 1)
        .disabled(isOffRamp)

      offRampControl
    }
  }

  // MARK: - Track

  @ViewBuilder private var track: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(Array(SchoolStatus.pipeline.enumerated()), id: \.element) { index, status in
        node(for: status)

        if index < SchoolStatus.pipeline.count - 1 {
          connector(after: status)
        }
      }
    }
  }

  private func node(for status: SchoolStatus) -> some View {
    let state = nodeState(for: status)

    return Button {
      Task { await onSelect(status) }
    } label: {
      VStack(spacing: 6) {
        ZStack {
          Circle()
            .fill(state.fill)
            .frame(width: 28, height: 28)
          Circle()
            .strokeBorder(state.stroke, lineWidth: 2)
            .frame(width: 28, height: 28)
          state.glyph
        }

        Text(status.stepperLabel)
          .font(.caption2)
          .fontWeight(state == .current ? .semibold : .regular)
          .foregroundStyle(state == .upcoming ? Color.secondary : Color.primary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
    .disabled(isUpdating)
    .accessibilityLabel(Text("\(status.displayName), \(state.accessibilityDescription)"))
    .accessibilityHint(Text("Double tap to set status to \(status.displayName)"))
    .accessibilityAddTraits(state == .current ? [.isButton, .isSelected] : .isButton)
  }

  private func connector(after status: SchoolStatus) -> some View {
    // The segment leading INTO a node is "done" once that node is reached.
    let done = currentStatus.rank > status.rank && !isOffRamp
    return Rectangle()
      .fill(done ? Color.accentColor : Color(.systemGray4))
      .frame(height: 2)
      .frame(maxWidth: .infinity)
      .padding(.top, 13)
      .accessibilityHidden(true)
  }

  // MARK: - Off-ramp

  @ViewBuilder
  private var offRampControl: some View {
    if isOffRamp {
      HStack(spacing: 8) {
        Image(systemName: "pause.circle.fill")
          .foregroundStyle(.secondary)
        Text("Not pursuing")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Reactivate") {
          Task { await onSelect(.researching) }
        }
        .font(.subheadline.weight(.semibold))
        .disabled(isUpdating)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(Color(.systemGray6))
      .clipShape(.rect(cornerRadius: 8))
    } else {
      Button(role: .destructive) {
        Task { await onSelect(.notPursuing) }
      } label: {
        Label("Mark not pursuing", systemImage: "xmark.circle")
          .font(.subheadline)
      }
      .disabled(isUpdating)
      .accessibilityHint(Text("Removes this school from the active recruiting funnel"))
    }
  }

  // MARK: - Node state

  private enum NodeState: Equatable {
    case completed
    case current
    case upcoming

    var fill: Color {
      switch self {
      case .completed: return .accentColor
      case .current: return .accentColor.opacity(0.15)
      case .upcoming: return Color(.systemBackground)
      }
    }

    var stroke: Color {
      switch self {
      case .completed, .current: return .accentColor
      case .upcoming: return Color(.systemGray4)
      }
    }

    @ViewBuilder var glyph: some View {
      switch self {
      case .completed:
        Image(systemName: "checkmark")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(Color(.systemBackground))
      case .current:
        Circle()
          .fill(Color.accentColor)
          .frame(width: 10, height: 10)
      case .upcoming:
        EmptyView()
      }
    }

    var accessibilityDescription: String {
      switch self {
      case .completed: return String(localized: "completed")
      case .current: return String(localized: "current stage")
      case .upcoming: return String(localized: "upcoming")
      }
    }
  }

  private func nodeState(for status: SchoolStatus) -> NodeState {
    if isOffRamp { return .upcoming }
    if status == currentStatus { return .current }
    return currentStatus.rank > status.rank ? .completed : .upcoming
  }
}

#Preview("Mid-funnel") {
  SchoolStatusStepper(currentStatus: .visiting, isUpdating: false, onSelect: { _ in })
    .padding()
}

#Preview("Off-ramp") {
  SchoolStatusStepper(currentStatus: .notPursuing, isUpdating: false, onSelect: { _ in })
    .padding()
}
