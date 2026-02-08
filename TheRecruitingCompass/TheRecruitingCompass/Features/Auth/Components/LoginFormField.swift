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
        .foregroundColor(Color.darkSlate)
        .accessibilityHidden(true)

      HStack(spacing: 12) {
        Image(systemName: icon)
          .foregroundColor(Color.iconGray)
          .frame(width: iconWidth)
          .accessibilityHidden(true)

        inputField
      }
      .padding(12)
      .background(Color.white)
      .border(error != nil ? Color.red : Color.borderGray, width: 1)
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
  @State var text = ""
  @State var error: String? = nil

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
