import SwiftUI

struct CoachesPresentSection: View {
  let schoolId: String?
  let coachesAtEvent: [Coach]
  let availableCoaches: [Coach]
  @Binding var selectedCoachId: String?
  let onRemoveCoach: (String) async -> Void
  let onAddCoach: () async -> Void

  private var emptyStateText: String? {
    if schoolId == nil || schoolId?.isEmpty == true {
      return "Event not linked to school"
    }
    if coachesAtEvent.isEmpty && availableCoaches.isEmpty {
      return "No coaches recorded"
    }
    return nil
  }

  private var canAddCoach: Bool {
    schoolId != nil && !schoolId!.isEmpty && !availableCoaches.isEmpty
  }

  var body: some View {
    Section {
      if let emptyText = emptyStateText {
        Text(emptyText)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityLabel(emptyText)
      }

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

      if canAddCoach {
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
