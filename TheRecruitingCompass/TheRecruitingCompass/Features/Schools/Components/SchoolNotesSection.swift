import SwiftUI

struct SchoolNotesSection: View {
  let title: String
  @Binding var notes: String
  let onBlur: () async -> Void

  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()
      }

      TextEditor(text: $notes)
        .frame(minHeight: 120)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .focused($isFocused)
        .accessibilityIdentifier("\(title.lowercased().replacing(" ", with: "-"))-text-editor")
        .accessibilityLabel(String(localized: "\(title) text editor"))
        .accessibilityHint("Enter your \(title.lowercased())")
        .accessibilityValue(notes.isEmpty ? "Empty" : notes)
        .onChange(of: isFocused) { _, focused in
          if !focused {
            Task { await onBlur() }
          }
        }
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(.rect(cornerRadius: 12))
  }
}

#Preview {
  @Previewable @State var notes = "Great academic program with strong baseball history."

  SchoolNotesSection(
    title: "Notes",
    notes: $notes,
    onBlur: {}
  )
  .padding()
}
