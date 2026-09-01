import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "GettingStartedChecklist")

struct GettingStartedChecklistWidget: View {
  let nuxProgress: NuxProgress
  let schoolsCount: Int
  let coachesCount: Int
  let profileCompleteness: Double
  let isParent: Bool
  let onComplete: (NuxChecklistKey) -> Void
  let onDismiss: () -> Void
  let onResume: () -> Void

  @Environment(\.switchTab) private var switchTab
  @Environment(\.openMoreSection) private var openMoreSection

  private var isDismissed: Bool {
    nuxProgress.checklist.dismissedAt != nil
  }

  private var allComplete: Bool {
    nuxProgress.checklist.completedCount == NuxChecklistKey.allCases.count
  }

  var body: some View {
    if isDismissed {
      resumeBanner
    } else if !allComplete {
      checklistCard
    }
  }

  // MARK: - Checklist Card

  @ViewBuilder
  private var checklistCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Getting Started")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)

          Text("\(nuxProgress.checklist.completedCount) of \(NuxChecklistKey.allCases.count)")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }

        Spacer()

        Button(role: .cancel) {
          onDismiss()
        } label: {
          Text("I'm good for now")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Dismiss getting started checklist"))
      }

      ProgressView(
        value: Double(nuxProgress.checklist.completedCount),
        total: Double(NuxChecklistKey.allCases.count)
      )
      .tint(Color.accentBlue)
      .accessibilityLabel(String(localized: "Getting started progress"))
      .accessibilityValue(String(localized: "\(nuxProgress.checklist.percentage) percent complete"))

      Divider()

      VStack(spacing: 0) {
        ForEach(NuxChecklistKey.allCases, id: \.rawValue) { key in
          checklistRow(for: key)

          if key != NuxChecklistKey.allCases.last {
            Divider()
              .padding(.leading, 36)
          }
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }

  @ViewBuilder
  private func checklistRow(for key: NuxChecklistKey) -> some View {
    let isCompleted = nuxProgress.isItemCompleted(key)

    Button {
      if !isCompleted {
        navigateToDestination(for: key)
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isCompleted ? Color.successGreen : Color.secondaryText)
          .font(.title3)
          .accessibilityHidden(true)

        Text(label(for: key))
          .font(.subheadline)
          .foregroundStyle(isCompleted ? Color.secondaryText : .primary)
          .strikethrough(isCompleted)
          .frame(maxWidth: .infinity, alignment: .leading)

        if !isCompleted {
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .accessibilityHidden(true)
        }
      }
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isCompleted)
    .accessibilityLabel(label(for: key))
    .accessibilityValue(isCompleted ? String(localized: "Completed") : String(localized: "Not completed"))
    .accessibilityHint(isCompleted ? "" : String(localized: "Tap to get started"))
  }

  // MARK: - Resume Banner

  @ViewBuilder
  private var resumeBanner: some View {
    Button {
      onResume()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "arrow.uturn.backward.circle")
          .foregroundStyle(Color.accentBlue)
          .accessibilityHidden(true)

        Text("Resume getting started")
          .font(.subheadline)
          .foregroundStyle(Color.accentBlue)

        Spacer()

        Text("\(nuxProgress.checklist.completedCount)/\(NuxChecklistKey.allCases.count)")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color.accentBlue.opacity(0.08))
      .clipShape(.rect(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(String(localized: "Resume getting started checklist"))
    .accessibilityHint(String(localized: "\(nuxProgress.checklist.completedCount) of \(NuxChecklistKey.allCases.count) items completed"))
  }

  // MARK: - Labels

  private func label(for key: NuxChecklistKey) -> String {
    switch key {
    case .sport:
      return isParent
        ? String(localized: "Set your athlete's sport")
        : String(localized: "Pick your sport")
    case .firstSchool:
      return isParent
        ? String(localized: "Add a school to track")
        : String(localized: "Add your first school")
    case .academics:
      return isParent
        ? String(localized: "Add academic info")
        : String(localized: "Enter your GPA and test scores")
    case .firstCoach:
      return isParent
        ? String(localized: "Save a coach contact")
        : String(localized: "Save your first coach")
    case .inviteFamily:
      return isParent
        ? String(localized: "Invite a family member")
        : String(localized: "Invite a parent or guardian")
    case .profile80:
      return isParent
        ? String(localized: "Help complete the profile")
        : String(localized: "Get your profile to 80%")
    case .previewTemplate:
      return isParent
        ? String(localized: "Preview an outreach template")
        : String(localized: "Preview a coach email")
    case .checkTimeline:
      return isParent
        ? String(localized: "Review the timeline")
        : String(localized: "Check your recruiting timeline")
    }
  }

  // MARK: - Navigation

  private func navigateToDestination(for key: NuxChecklistKey) {
    switch key {
    case .sport, .academics, .profile80:
      openMoreSection(.settings)
    case .firstSchool:
      switchTab(.schools)
    case .firstCoach:
      switchTab(.coaches)
    case .inviteFamily:
      // Uses NavigationLink destination handled by DashboardView's navigation stack
      break
    case .previewTemplate:
      switchTab(.coaches)
    case .checkTimeline:
      openMoreSection(.timeline)
    }
  }
}

#Preview {
  GettingStartedChecklistWidget(
    nuxProgress: .empty,
    schoolsCount: 0,
    coachesCount: 0,
    profileCompleteness: 0.3,
    isParent: false,
    onComplete: { _ in },
    onDismiss: {},
    onResume: {}
  )
  .padding()
}
