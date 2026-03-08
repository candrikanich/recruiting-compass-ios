import SwiftUI

/// Parent mode banner for Tasks: "Viewing [Athlete Name]'s Tasks (Read-Only)".
struct TasksParentBanner: View {
  let athleteName: String
  let onDismiss: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  private var fontSize: CGFloat {
    sizeCategory >= .extraLarge ? 16 : 14
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "eye")
        .font(.system(size: fontSize))
        .foregroundStyle(.white)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text("Parent Preview Mode")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white)
        Text("Viewing \(athleteName)'s Tasks (Read-Only)")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.9))
      }

      Spacer()

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: fontSize + 2))
          .foregroundStyle(.white.opacity(0.9))
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Exit preview mode")
      .accessibilityHint("Returns to athlete selection")
    }
    .padding()
    .background(
      LinearGradient(
        gradient: Gradient(colors: [Color.accentBlue, Color(hex: "#2563EB")]),
        startPoint: .leading,
        endPoint: .trailing
      )
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Parent preview mode, viewing \(athleteName)'s tasks, read only")
  }
}

#Preview {
  TasksParentBanner(athleteName: "Jordan", onDismiss: {})
}
