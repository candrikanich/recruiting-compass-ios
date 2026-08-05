import SwiftUI

struct Toast: View {
  let message: String
  let type: ToastType
  let onDismiss: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: type.iconName)
        .font(.body)
        .foregroundStyle(type.iconColor)
        .accessibilityHidden(true)

      Text(message)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)

      Spacer()

      Button {
        onDismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel(String(localized: "Dismiss notification"))
    }
    .padding(16)
    .background(Color.Surface.card, in: RoundedRectangle(cornerRadius: 12))
    .brandShadowMd()
    .padding(.horizontal, 16)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(message)
    .accessibilityAddTraits(.updatesFrequently)
  }
}

#Preview {
  VStack(spacing: 16) {
    Toast(message: "Coach deleted successfully", type: .success) {}
    Toast(message: "Coach and 3 interactions deleted", type: .success) {}
    Toast(message: "Failed to delete coach", type: .error) {}
    Toast(message: "New coach added", type: .info) {}
  }
}
