import SwiftUI

struct PasswordFormField: View {
  let label: String
  let placeholder: String
  @Binding var text: String
  @Binding var error: String?
  @Binding var isPasswordVisible: Bool
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
        Image(systemName: "lock")
          .foregroundColor(Color.iconGray)
          .frame(width: iconWidth)
          .accessibilityHidden(true)

        if isPasswordVisible {
          TextField(placeholder, text: $text)
            .accessibilityLabel(label)
            .accessibilityHint(error ?? "")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(onBlur)
        } else {
          SecureField(placeholder, text: $text)
            .accessibilityLabel(label)
            .accessibilityHint(error ?? "")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(onBlur)
        }

        Button(action: { isPasswordVisible.toggle() }) {
          Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
            .foregroundColor(Color.iconGray)
            .frame(width: iconWidth)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
        .accessibilityHint("Double tap to \(isPasswordVisible ? "hide" : "show") password text")
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
  @Previewable @State var text = ""
  @Previewable @State var error: String? = nil
  @Previewable @State var isVisible = false

  PasswordFormField(
    label: "New Password",
    placeholder: "Enter your new password",
    text: $text,
    error: $error,
    isPasswordVisible: $isVisible,
    onBlur: {}
  )
  .padding()
}
