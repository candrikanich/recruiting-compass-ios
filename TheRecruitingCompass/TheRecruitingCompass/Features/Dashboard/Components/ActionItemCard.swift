import SwiftUI

struct ActionItemCard: View {
  let suggestion: Suggestion
  let familyUnitId: String
  let userId: String
  let onDismiss: () -> Void
  let onComplete: () -> Void
  /// Called after an add-school/add-interaction sheet is dismissed so the host can refresh.
  let onActionCompleted: () -> Void

  @State private var showHelp = false
  @State private var activeSheet: CardSheet?

  private enum CardSheet: Identifiable {
    case addSchool
    case addInteraction
    case videoLinks
    var id: Int { hashValue }
  }

  private var cta: ActionItemCTA { ActionItemCTA(actionType: suggestion.actionType) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 12) {
        Circle()
          .fill(suggestion.urgency.color)
          .frame(width: 8, height: 8)
          .padding(.top, 6)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(suggestion.urgency.displayName)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(suggestion.urgency.color.opacity(0.15))
            .foregroundStyle(suggestion.urgency.color)
            .clipShape(.rect(cornerRadius: 4))
            .accessibilityHidden(true)

          Text(suggestion.message)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Color.primary)
            .lineLimit(3)

          Button(String(localized: "Learn More")) { showHelp = true }
            .font(.subheadline)
            .foregroundStyle(Color.accentBlue)
            .accessibilityHint("Shows detailed guidance for this suggestion")
        }

        Spacer()
      }

      actionRow
    }
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .sheet(isPresented: $showHelp) {
      SuggestionHelpModal(ruleType: suggestion.ruleType, urgency: suggestion.urgency)
    }
    .sheet(item: $activeSheet, onDismiss: onActionCompleted) { sheet in
      switch sheet {
      case .addSchool:
        ActionItemAddSchoolSheet(familyUnitId: familyUnitId, userId: userId)
      case .addInteraction:
        ActionItemAddInteractionSheet(familyUnitId: familyUnitId, userId: userId)
      case .videoLinks:
        ActionItemVideoLinksSheet(userId: userId, familyUnitId: familyUnitId)
      }
    }
  }

  @ViewBuilder
  private var actionRow: some View {
    HStack(spacing: 12) {
      if let label = cta.label {
        Button(label) { presentCTA() }
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(suggestion.urgency.color)
          .foregroundStyle(Color.white)
          .clipShape(.rect(cornerRadius: 8))
          .accessibilityHint("Opens the screen to complete this action")
      }

      Spacer(minLength: 8)

      iconLabelButton(
        systemName: "checkmark.circle.fill",
        title: String(localized: "Done"),
        tint: Color.accentBlue,
        action: onComplete
      )
      .accessibilityLabel(String(localized: "Complete suggestion"))
      .accessibilityHint("Mark this suggestion as done")

      iconLabelButton(
        systemName: "xmark.circle.fill",
        title: String(localized: "Dismiss"),
        tint: Color.gray,
        action: onDismiss
      )
      .accessibilityLabel(String(localized: "Dismiss suggestion"))
      .accessibilityHint("Hide this suggestion without completing it")
    }
  }

  private func iconLabelButton(
    systemName: String,
    title: String,
    tint: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 2) {
        Image(systemName: systemName)
          .font(.title3)
        Text(title)
          .font(.caption2)
      }
      .foregroundStyle(tint)
      .frame(minWidth: 52, minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func presentCTA() {
    switch cta {
    case .addSchool: activeSheet = .addSchool
    case .logInteraction: activeSheet = .addInteraction
    case .addVideo, .updateVideo: activeSheet = .videoLinks
    case .none: break
    }
  }
}
