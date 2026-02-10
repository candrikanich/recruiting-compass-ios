import SwiftUI

struct NotesSection: View {
  let title: String
  let notes: String
  let isEditing: Bool
  @Binding var editedNotes: String
  let onEdit: () -> Void
  let onSave: () async -> Void
  let onCancel: () -> Void
  let isPrivate: Bool
  let isSaving: Bool

  @Environment(\.sizeCategory) private var sizeCategory
  @FocusState private var isTextEditorFocused: Bool

  private var minEditorHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 150 : 100
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title)
          .font(sizeCategory.isAccessibilityCategory ? .title3.bold() : .headline.bold())
          .foregroundColor(.primary)

        Spacer()

        if !isEditing {
          Button(action: {
            onEdit()
            isTextEditorFocused = true
          }) {
            Text("Edit")
              .font(.subheadline.weight(.medium))
              .foregroundColor(.accentBlue)
          }
          .accessibilityLabel("Edit \(title.lowercased())")
        }
      }

      if isPrivate {
        Text("Only visible to you")
          .font(.caption)
          .foregroundColor(.secondaryText)
          .accessibilityHidden(true)
      }

      if isEditing {
        TextEditor(text: $editedNotes)
          .frame(minHeight: minEditorHeight)
          .padding(8)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.borderGray, lineWidth: 1)
          )
          .focused($isTextEditorFocused)
          .accessibilityLabel("\(title) editor")

        HStack(spacing: 12) {
          Button(action: onCancel) {
            Text("Cancel")
              .font(.subheadline.weight(.medium))
              .frame(maxWidth: .infinity, minHeight: 44)
              .foregroundColor(.secondaryText)
              .background(Color(.systemGray5))
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .disabled(isSaving)
          .accessibilityLabel("Cancel editing \(title.lowercased())")

          Button(action: {
            Task {
              await onSave()
            }
          }) {
            if isSaving {
              ProgressView()
                .frame(maxWidth: .infinity, minHeight: 44)
            } else {
              Text("Save")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundColor(.white)
                .background(Color.accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
          }
          .disabled(isSaving)
          .accessibilityLabel("Save \(title.lowercased())")
        }
      } else {
        if notes.isEmpty {
          Text("No notes")
            .font(.body)
            .foregroundColor(.secondaryText)
            .italic()
        } else {
          Text(notes)
            .font(.body)
            .foregroundColor(.primary)
        }
      }
    }
    .padding(16)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
  }
}

#Preview("Shared Notes - Read Mode") {
  NotesSection(
    title: "Shared Notes",
    notes: "Great recruiter, very responsive to emails. Prefers morning communication.",
    isEditing: false,
    editedNotes: .constant(""),
    onEdit: {},
    onSave: {},
    onCancel: {},
    isPrivate: false,
    isSaving: false
  )
  .padding()
}

#Preview("Private Notes - Edit Mode") {
  NotesSection(
    title: "Private Notes",
    notes: "",
    isEditing: true,
    editedNotes: .constant("My private thoughts about this coach..."),
    onEdit: {},
    onSave: {},
    onCancel: {},
    isPrivate: true,
    isSaving: false
  )
  .padding()
}

#Preview("Empty Notes") {
  NotesSection(
    title: "Shared Notes",
    notes: "",
    isEditing: false,
    editedNotes: .constant(""),
    onEdit: {},
    onSave: {},
    onCancel: {},
    isPrivate: false,
    isSaving: false
  )
  .padding()
}
