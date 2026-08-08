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
      }
    }
  }

  @ViewBuilder
  private var actionRow: some View {
    HStack(spacing: 16) {
      if let label = cta.label {
        Button(label) { presentCTA() }
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(suggestion.urgency.color)
          .foregroundStyle(Color.white)
          .clipShape(.rect(cornerRadius: 8))
          .accessibilityHint("Opens the screen to complete this action")
      }

      Button(String(localized: "Learn More")) { showHelp = true }
        .font(.subheadline)
        .foregroundStyle(Color.accentBlue)
        .accessibilityHint("Shows detailed guidance for this suggestion")

      Spacer()

      Button(action: onComplete) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(Color.accentBlue)
          .font(.title3)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "Complete suggestion"))
      .accessibilityHint("Mark this suggestion as done")

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(Color.gray)
          .font(.title3)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "Dismiss suggestion"))
      .accessibilityHint("Hide this suggestion without completing it")
    }
  }

  private func presentCTA() {
    switch cta {
    case .addSchool: activeSheet = .addSchool
    case .logInteraction: activeSheet = .addInteraction
    case .none: break
    }
  }
}
