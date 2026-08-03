import SwiftUI
import UIKit

/// Applies textContentType when non-nil; fixes iOS suggestion bubble truncation/overlap.
private struct TextContentTypeModifier: ViewModifier {
  let contentType: UITextContentType?

  func body(content: Content) -> some View {
    if let contentType {
      content.textContentType(contentType)
    } else {
      content
    }
  }
}

struct LoginFormField: View {
  let label: String
  let placeholder: String
  let icon: String
  @Binding var text: String
  @Binding var error: String?
  let isSecure: Bool
  let keyboardType: UIKeyboardType
  /// Semantic type for autofill/suggestions. Set to fix truncated or overlapping iOS suggestion bubbles.
  var textContentType: UITextContentType?
  /// Optional identifier for UI testing (E2E).
  var accessibilityIdentifier: String?
  let onBlur: () -> Void
  @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 20

  @ViewBuilder
  private var inputField: some View {
    Group {
      if isSecure {
        SecureField(placeholder, text: $text)
      } else {
        TextField(placeholder, text: $text)
          .keyboardType(keyboardType)
      }
    }
    .foregroundStyle(Color.primary)
    .accessibilityLabel(label)
    .accessibilityValue(error.map { "Error: \($0)" } ?? "")
    .autocorrectionDisabled()
    .textInputAutocapitalization(.never)
    .modifier(TextContentTypeModifier(contentType: textContentType))
    .onSubmit(onBlur)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.primary)
        .accessibilityHidden(true)

      HStack(spacing: 12) {
        Image(systemName: icon)
          .foregroundStyle(Color.secondary)
          .frame(width: iconWidth)
          .accessibilityHidden(true)

        inputField
      }
      .padding(12)
      .background(Color(uiColor: .secondarySystemBackground))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(error != nil ? Color.red : Color(uiColor: .separator), lineWidth: 1)
      )
      .clipShape(.rect(cornerRadius: 8))

      if let error {
        Text(error)
          .font(.caption)
          .foregroundStyle(Color.errorRed)
          .accessibilityLabel("Error: \(error)")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(accessibilityIdentifier ?? label)
  }
}

#Preview {
  @Previewable @State var text = ""
  @Previewable @State var error: String?

  return LoginFormField(
    label: "Email",
    placeholder: "your.email@example.com",
    icon: "envelope",
    text: $text,
    error: $error,
    isSecure: false,
    keyboardType: .emailAddress,
    onBlur: {}
  )
  .padding()
}
