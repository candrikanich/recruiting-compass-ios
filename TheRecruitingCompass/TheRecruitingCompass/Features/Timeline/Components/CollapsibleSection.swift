import SwiftUI

/// Shared card chrome + per-section collapse for Timeline Guidance widgets.
/// Owns the card background/border/shadow and title header (with chevron);
/// callers supply only their content. `maxWidth: .infinity` on the container
/// is what makes all wrapped sections render at equal width.
struct CollapsibleSection<Content: View>: View {
  let title: String
  let isExpanded: Bool
  let onToggle: () -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button(action: onToggle) {
        HStack {
          Text(title)
            .font(.headline)
          Spacer()
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundStyle(Color.secondaryText)
        }
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(.isHeader)

      if isExpanded {
        content()
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }
}
