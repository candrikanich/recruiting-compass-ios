import SwiftUI

struct SchoolNotesSection: View {
  let title: String
  let notes: String
  let isPrivate: Bool
  let isEditing: Bool
  @Binding var editedNotes: String
  let onEdit: () -> Void
  let onSave: () async -> Void
  let onCancel: () -> Void
  let isSaving: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()

        if !isEditing {
          Button("Edit", action: onEdit)
            .accessibilityIdentifier("\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-edit-button")
            .accessibilityLabel("Edit \(title.lowercased())")
        }
      }

      if isPrivate {
        Text("Only you can see these notes")
          .font(.caption)
          .foregroundStyle(.secondary)
          .italic()
      }

      if isEditing {
        VStack(spacing: 12) {
          TextEditor(text: $editedNotes)
            .frame(minHeight: 120)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .accessibilityIdentifier("\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-text-editor")
            .accessibilityLabel("\(title) text editor")
            .accessibilityHint("Enter your \(title.lowercased())")
            .accessibilityValue(editedNotes.isEmpty ? "Empty" : editedNotes)

          HStack {
            Button("Cancel", action: onCancel)
              .accessibilityIdentifier("\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-cancel-button")
              .disabled(isSaving)

            Spacer()

            Button {
              Task { await onSave() }
            } label: {
              if isSaving {
                ProgressView()
                  .progressViewStyle(.circular)
                  .scaleEffect(0.8)
                  .accessibilityLabel("Saving \(title.lowercased())")
              } else {
                Text("Save")
              }
            }
            .accessibilityIdentifier("\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-save-button")
            .accessibilityLabel(isSaving ? "Saving \(title.lowercased())" : "Save \(title.lowercased())")
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
          }
        }
      } else {
        Text(notes.isEmpty ? "No notes added yet." : notes)
          .font(.body)
          .foregroundStyle(notes.isEmpty ? .secondary : .primary)
          .italic(notes.isEmpty)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

#Preview {
  VStack(spacing: 16) {
    SchoolNotesSection(
      title: "Notes",
      notes: "Great academic program with strong baseball history.",
      isPrivate: false,
      isEditing: false,
      editedNotes: .constant(""),
      onEdit: {},
      onSave: {},
      onCancel: {},
      isSaving: false
    )

    SchoolNotesSection(
      title: "Private Notes",
      notes: "",
      isPrivate: true,
      isEditing: true,
      editedNotes: .constant("My private thoughts..."),
      onEdit: {},
      onSave: {},
      onCancel: {},
      isSaving: false
    )
  }
  .padding()
}
