import SwiftUI

struct ParentPreviewBanner: View {
  let athleteName: String
  let onDismiss: () -> Void

  @Environment(\.sizeCategory) var sizeCategory

  private var fontSize: CGFloat {
    sizeCategory >= .extraLarge ? 16 : 14
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "eye")
        .font(.system(size: fontSize))
        .foregroundColor(.white)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text("Parent Preview Mode")
          .font(.system(size: fontSize, weight: .semibold))
          .foregroundColor(.white)

        Text("Viewing \(athleteName)'s dashboard")
          .font(.system(size: fontSize - 2))
          .foregroundColor(.white.opacity(0.9))
      }

      Spacer()

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: fontSize + 2))
          .foregroundColor(.white.opacity(0.9))
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(PlainButtonStyle())
      .accessibilityLabel("Exit preview mode")
      .accessibilityHint("Returns to your athlete selection view")
    }
    .padding()
    .background(
      LinearGradient(
        gradient: Gradient(colors: [Color.accentBlue, Color(hex: "#2563EB")]),
        startPoint: .leading,
        endPoint: .trailing
      )
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Parent preview mode active, viewing \(athleteName)'s dashboard")
  }
}

#Preview {
  ParentPreviewBanner(
    athleteName: "John Smith",
    onDismiss: {}
  )
}
