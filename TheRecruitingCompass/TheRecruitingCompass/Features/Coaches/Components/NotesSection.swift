import SwiftUI

struct NotesSection: View {
  let title: String
  @Binding var notes: String
  let onBlur: () async -> Void

  @Environment(\.sizeCategory) private var sizeCategory
  @FocusState private var isFocused: Bool

  private var minEditorHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 150 : 100
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title)
          .font(sizeCategory.isAccessibilityCategory ? .title3.bold() : .headline.bold())
          .foregroundStyle(.primary)

        Spacer()
      }

      TextEditor(text: $notes)
        .frame(minHeight: minEditorHeight)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(isFocused ? Color.accentBlue : Color.borderGray, lineWidth: isFocused ? 2 : 1)
        )
        .focused($isFocused)
        .accessibilityLabel("\(title) editor")
        .onChange(of: isFocused) { _, focused in
          if !focused {
            Task { await onBlur() }
          }
        }
    }
    .padding(16)
    .background(Color.Surface.card)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .brandShadowMd()
  }
}

#Preview("Shared Notes") {
  @Previewable @State var notes = "Great recruiter, very responsive to emails."
  NotesSection(
    title: "Shared Notes",
    notes: $notes,
    onBlur: {}
  )
  .padding()
}
