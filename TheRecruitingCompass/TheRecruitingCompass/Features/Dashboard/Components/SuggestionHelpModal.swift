import SwiftUI

/// "Learn More" detail sheet for an action item, keyed by rule type.
struct SuggestionHelpModal: View {
  let ruleType: String
  let urgency: Suggestion.UrgencyLevel

  @Environment(\.dismiss) private var dismiss

  private var content: SuggestionHelpContent { SuggestionHelpContent.content(for: ruleType) }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          section(title: String(localized: "Why It Matters")) {
            Text(content.whyItMatters)
              .font(.brand(.body))
              .foregroundStyle(Color.primary)
          }

          section(title: String(localized: "How to Complete")) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(Array(content.howToComplete.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                  Text("\(index + 1).")
                    .font(.brand(.body))
                    .fontWeight(.semibold)
                    .foregroundStyle(urgency.color)
                  Text(step)
                    .font(.brand(.body))
                    .foregroundStyle(Color.primary)
                }
              }
            }
          }

          section(title: String(localized: "What Coaches Expect")) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(content.coachesExpect, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(urgency.color)
                    .accessibilityHidden(true)
                  Text(item)
                    .font(.brand(.body))
                    .foregroundStyle(Color.primary)
                }
              }
            }
          }

          section(title: String(localized: "Timeline")) {
            Text(content.timeline)
              .font(.brand(.subheadline))
              .foregroundStyle(Color.secondaryText)
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle(content.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "Done")) { dismiss() }
        }
      }
    }
  }

  @ViewBuilder
  private func section<Body: View>(title: String, @ViewBuilder content: () -> Body) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.brand(.headline))
        .foregroundStyle(Color.primary)
      content()
    }
  }
}

#Preview {
  SuggestionHelpModal(ruleType: "school-list-building", urgency: .medium)
}
