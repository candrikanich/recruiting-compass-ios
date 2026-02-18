import SwiftUI

struct CoachesPresentSection: View {
  let coachesAtEvent: [Coach]
  let availableCoaches: [Coach]
  @Binding var selectedCoachId: String?
  let onRemoveCoach: (String) async -> Void
  let onAddCoach: () async -> Void

  var body: some View {
    Section {
      ForEach(coachesAtEvent) { coach in
        HStack {
          EventCoachCard(coach: coach)
          Spacer()
          Button(role: .destructive) {
            Task { await onRemoveCoach(coach.id) }
          } label: {
            Image(systemName: "minus.circle.fill")
              .foregroundStyle(.red)
          }
          .buttonStyle(.plain)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
          .accessibilityLabel("Remove \(coach.fullName)")
        }
      }

      if !availableCoaches.isEmpty {
        Picker("Add Coach", selection: Binding(
          get: { selectedCoachId ?? "" },
          set: { selectedCoachId = $0.isEmpty ? nil : $0 }
        )) {
          Text("Select a coach...").tag("")
          ForEach(availableCoaches) { coach in
            Text(coach.fullName).tag(coach.id)
          }
        }
        .accessibilityLabel("Add coach to event")
        .onChange(of: selectedCoachId) { _, newValue in
          if newValue != nil {
            Task { await onAddCoach() }
          }
        }
      }
    } header: {
      HStack {
        Text("Coaches Present")
        Spacer()
        Text("\(coachesAtEvent.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
