import SwiftUI

struct EditableCoachingPhilosophy: Sendable {
  var coachingPhilosophy: String
  var coachingStyle: String
  var recruitingApproach: String
  var communicationStyle: String
  var successMetrics: String

  init(
    coachingPhilosophy: String = "",
    coachingStyle: String = "",
    recruitingApproach: String = "",
    communicationStyle: String = "",
    successMetrics: String = ""
  ) {
    self.coachingPhilosophy = coachingPhilosophy
    self.coachingStyle = coachingStyle
    self.recruitingApproach = recruitingApproach
    self.communicationStyle = communicationStyle
    self.successMetrics = successMetrics
  }

  static func from(school: School) -> EditableCoachingPhilosophy {
    EditableCoachingPhilosophy(
      coachingPhilosophy: school.coachingPhilosophy ?? "",
      coachingStyle: school.coachingStyle ?? "",
      recruitingApproach: school.recruitingApproach ?? "",
      communicationStyle: school.communicationStyle ?? "",
      successMetrics: school.successMetrics ?? ""
    )
  }
}

struct SchoolCoachingPhilosophySheet: View {
  @Binding var philosophy: EditableCoachingPhilosophy
  let onSave: () async -> Void
  let onCancel: () -> Void
  let isSaving: Bool

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          PhilosophyField(
            title: "Coaching Philosophy",
            text: $philosophy.coachingPhilosophy,
            placeholder: "What's the overall coaching approach?"
          )
        }

        Section {
          PhilosophyField(
            title: "Coaching Style",
            text: $philosophy.coachingStyle,
            placeholder: "How does the coach interact with players?"
          )
        }

        Section {
          PhilosophyField(
            title: "Recruiting Approach",
            text: $philosophy.recruitingApproach,
            placeholder: "What type of players do they recruit?"
          )
        }

        Section {
          PhilosophyField(
            title: "Communication Style",
            text: $philosophy.communicationStyle,
            placeholder: "How do they communicate with recruits and families?"
          )
        }

        Section {
          PhilosophyField(
            title: "Success Metrics",
            text: $philosophy.successMetrics,
            placeholder: "How do they measure success?"
          )
        }
      }
      .navigationTitle("Coaching Philosophy")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onCancel()
            dismiss()
          }
          .disabled(isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              await onSave()
              dismiss()
            }
          } label: {
            if isSaving {
              ProgressView()
                .progressViewStyle(.circular)
                .accessibilityLabel("Saving")
            } else {
              Text("Save")
            }
          }
          .disabled(isSaving)
        }
      }
    }
  }
}

private struct PhilosophyField: View {
  let title: String
  @Binding var text: String
  let placeholder: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline)
        .fontWeight(.medium)

      TextEditor(text: $text)
        .frame(minHeight: 100)
        .scrollContentBackground(.hidden)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
          if text.isEmpty {
            Text(placeholder)
              .foregroundStyle(.tertiary)
              .padding(.leading, 12)
              .padding(.top, 16)
              .allowsHitTesting(false)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          }
        }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
    .accessibilityValue(text.isEmpty ? "Empty" : text)
  }
}

#Preview {
  SchoolCoachingPhilosophySheet(
    philosophy: .constant(EditableCoachingPhilosophy(
      coachingPhilosophy: "Player development first",
      coachingStyle: "Positive reinforcement",
      recruitingApproach: "Character over talent",
      communicationStyle: "Open and frequent",
      successMetrics: "Player growth and team culture"
    )),
    onSave: {},
    onCancel: {},
    isSaving: false
  )
}
