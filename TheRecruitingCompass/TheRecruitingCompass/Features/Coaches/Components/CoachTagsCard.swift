import SwiftUI

/// Tag chips with add/remove — matching the coach-detail Figma frame. Wrapping
/// layout via SwiftUI's native `Layout` (`FlowLayout`). Caps are enforced by the
/// view model's sanitizer on persist.
struct CoachTagsCard: View {
  let tags: [String]
  var onAdd: (String) -> Void = { _ in }
  var onRemove: (String) -> Void = { _ in }

  @State private var isAddingTag = false
  @State private var draftTag = ""

  var body: some View {
    FlowLayout(spacing: 8) {
      ForEach(tags, id: \.self) { tag in
        chip(tag)
      }
      addButton
    }
    .alert("Add Tag", isPresented: $isAddingTag) {
      TextField("Tag", text: $draftTag)
      Button("Add") {
        let trimmed = draftTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { onAdd(trimmed) }
        draftTag = ""
      }
      Button("Cancel", role: .cancel) { draftTag = "" }
    }
  }

  private func chip(_ tag: String) -> some View {
    HStack(spacing: 4) {
      Text(tag).font(.footnote)
      Button {
        onRemove(tag)
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .bold))
      }
      .accessibilityLabel("Remove tag \(tag)")
    }
    .foregroundStyle(Color.Brand.slate600)
    .padding(.horizontal, 10).padding(.vertical, 6)
    .background(Color.Brand.slate100)
    .clipShape(Capsule())
  }

  @ViewBuilder private var addButton: some View {
    Button {
      isAddingTag = true
    } label: {
      Label("Add Tag", systemImage: "plus")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.Brand.blue600)
    }
    .accessibilityLabel("Add tag")
  }
}
