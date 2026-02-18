import SwiftUI

struct QuickLogInteractionSheet: View {
  @Binding var data: InteractionData
  let coaches: [Coach]
  let isSubmitting: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        typeSection
        directionSection
        sentimentSection
        coachSection
        notesSection
      }
      .navigationTitle("Log Interaction")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
            .disabled(isSubmitting)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { onSave() }
            .fontWeight(.semibold)
            .disabled(isSubmitting)
        }
      }
      .interactiveDismissDisabled(isSubmitting)
    }
  }

  // MARK: - Sections

  private var typeSection: some View {
    Section {
      Picker("Type", selection: $data.type) {
        ForEach(InteractionType.allCases, id: \.self) { type in
          Label(type.displayName, systemImage: type.iconName)
            .tag(type)
        }
      }
      .accessibilityLabel("Interaction type")
    } header: {
      Text("Interaction Type")
    }
  }

  private var directionSection: some View {
    Section {
      Picker("Direction", selection: $data.direction) {
        ForEach(Direction.allCases, id: \.self) { direction in
          Text(direction.displayName).tag(direction)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityLabel("Interaction direction")
    } header: {
      Text("Direction")
    }
  }

  private var sentimentSection: some View {
    Section {
      Picker("Sentiment", selection: $data.sentiment) {
        ForEach(Sentiment.allCases, id: \.self) { sentiment in
          Text(sentiment.displayName).tag(sentiment)
        }
      }
      .accessibilityLabel("Interaction sentiment")
    } header: {
      Text("Sentiment")
    }
  }

  @ViewBuilder
  private var coachSection: some View {
    if !coaches.isEmpty {
      Section {
        Picker("Coach", selection: Binding(
          get: { data.coachId ?? "" },
          set: { data.coachId = $0.isEmpty ? nil : $0 }
        )) {
          Text("None").tag("")
          ForEach(coaches) { coach in
            Text(coach.fullName).tag(coach.id)
          }
        }
        .accessibilityLabel("Associated coach")
      } header: {
        Text("Coach (Optional)")
      }
    }
  }

  private var notesSection: some View {
    Section {
      TextField("Notes", text: $data.notes, axis: .vertical)
        .lineLimit(3...6)
        .accessibilityLabel("Interaction notes")
    } header: {
      Text("Notes (Optional)")
    }
  }
}
