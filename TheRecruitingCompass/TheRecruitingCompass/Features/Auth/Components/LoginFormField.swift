import SwiftUI
import UIKit

struct LoginFormField: View {
  let label: String
  let placeholder: String
  let icon: String
  @Binding var text: String
  @Binding var error: String?
  let isSecure: Bool
  let keyboardType: UIKeyboardType
  let onBlur: () -> Void
  @Environment(\.sizeCategory) var sizeCategory

  private var iconWidth: CGFloat {
    sizeCategory >= .extraLarge ? 22 : 20
  }

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
          .strokeBorder(error != nil ? Color.red : Color(uiColor: .separator), lineWidth: 1)
      )
      .cornerRadius(8)

      if let error = error {
        Text(error)
          .font(.caption)
          .foregroundColor(Color.errorRed)
          .accessibilityLabel("Error: \(error)")
      }
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  @Previewable @State var text = ""
  @Previewable @State var error: String? = nil

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
