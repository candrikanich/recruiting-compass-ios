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

  @ViewBuilder
  private var typeSection: some View {
    Section {
      Picker("Type", selection: $data.type) {
        ForEach(InteractionType.allCases, id: \.self) { type in
          Label(type.displayName, systemImage: type.iconName)
            .tag(type)
        }
      }
      .accessibilityLabel(String(localized: "Interaction type"))
    } header: {
      Text("Interaction Type")
    }
  }

  @ViewBuilder
  private var directionSection: some View {
    Section {
      Picker("Direction", selection: $data.direction) {
        ForEach(Direction.allCases, id: \.self) { direction in
          Text(direction.displayName).tag(direction)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityLabel(String(localized: "Interaction direction"))
    } header: {
      Text("Direction")
    }
  }

  @ViewBuilder
  private var sentimentSection: some View {
    Section {
      Picker("Sentiment", selection: $data.sentiment) {
        ForEach(Sentiment.allCases, id: \.self) { sentiment in
          Text(sentiment.displayName).tag(sentiment)
        }
      }
      .accessibilityLabel(String(localized: "Interaction sentiment"))
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
        .accessibilityLabel(String(localized: "Associated coach"))
      } header: {
        Text("Coach (Optional)")
      }
    }
  }

  @ViewBuilder
  private var notesSection: some View {
    Section {
      TextField("Notes", text: $data.notes, axis: .vertical)
        .lineLimit(3...6)
        .accessibilityLabel(String(localized: "Interaction notes"))
    } header: {
      Text("Notes (Optional)")
    }
  }
}
