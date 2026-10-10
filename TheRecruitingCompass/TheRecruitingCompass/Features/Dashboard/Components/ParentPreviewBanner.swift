import SwiftUI

struct ParentPreviewBanner: View {
  let athleteName: String
  let onDismiss: () -> Void

  @ScaledMetric(relativeTo: .subheadline) private var fontSize: CGFloat = 14

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "eye")
        .font(.system(size: fontSize))
        .foregroundStyle(Color.Surface.onBrandTint)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text("Parent Preview Mode")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.Surface.onBrandTint)

        Text("Viewing \(athleteName)'s dashboard")
          .font(.caption)
          .foregroundStyle(Color.Surface.onBrandTint)
      }

      Spacer()

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: fontSize + 2))
          .foregroundStyle(Color.Surface.onBrandTint)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "Exit preview mode"))
      .accessibilityHint("Returns to your athlete selection view")
    }
    .padding()
    .background(Color.Surface.brandTint)
    .overlay(alignment: .bottom) {
      Rectangle().fill(Color.Surface.brandTintBorder).frame(height: 1)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(String(localized: "Parent preview mode active, viewing \(athleteName)'s dashboard"))
  }
}

#Preview {
  ParentPreviewBanner(
    athleteName: "John Smith",
    onDismiss: {}
  )
}
