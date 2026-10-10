import SwiftUI

/// Parent mode banner for Tasks: "Viewing [Athlete Name]'s Tasks (Read-Only)".
struct TasksParentBanner: View {
  let athleteName: String
  let onDismiss: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "eye")
        .font(sizeCategory.isAccessibilityCategory ? .brand(.title3) : .brand(.subheadline))
        .foregroundStyle(Color.Surface.onBrandTint)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text("Parent Preview Mode")
          .font(.brand(.subheadline, weight: .semibold))
          .foregroundStyle(Color.Surface.onBrandTint)
        Text("Viewing \(athleteName)'s Tasks (Read-Only)")
          .font(.brand(.caption))
          .foregroundStyle(Color.Surface.onBrandTint)
      }

      Spacer()

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .font(sizeCategory.isAccessibilityCategory ? .brand(.title2) : .brand(.title3))
          .foregroundStyle(Color.Surface.onBrandTint)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "Exit preview mode"))
      .accessibilityHint("Returns to athlete selection")
    }
    .padding()
    .background(Color.Surface.brandTint)
    .overlay(alignment: .bottom) {
      Rectangle().fill(Color.Surface.brandTintBorder).frame(height: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Parent preview mode, viewing \(athleteName)'s tasks, read only"))
  }
}

#Preview {
  TasksParentBanner(athleteName: "Jordan", onDismiss: {})
}
