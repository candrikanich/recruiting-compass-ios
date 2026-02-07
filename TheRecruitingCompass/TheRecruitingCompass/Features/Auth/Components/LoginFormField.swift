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

        if isSecure {
          SecureField(placeholder, text: $text)
            .accessibilityLabel(label)
            .accessibilityHint(error != nil ? error! : "")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(onBlur)
        } else {
          TextField(placeholder, text: $text)
            .accessibilityLabel(label)
            .accessibilityHint(error != nil ? error! : "")
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(onBlur)
        }
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
