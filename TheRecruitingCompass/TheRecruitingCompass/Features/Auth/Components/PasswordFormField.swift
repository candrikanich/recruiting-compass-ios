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
        .foregroundColor(Color(red: 0.216, green: 0.263, blue: 0.322))
        .accessibilityHidden(true)

      HStack(spacing: 12) {
        Image(systemName: "lock")
          .foregroundColor(Color(red: 0.627, green: 0.655, blue: 0.686))
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
            .foregroundColor(Color(red: 0.627, green: 0.655, blue: 0.686))
            .frame(width: iconWidth)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
        .accessibilityHint("Double tap to \(isPasswordVisible ? "hide" : "show") password text")
      }
      .padding(12)
      .background(Color.white)
      .border(error != nil ? Color.red : Color(red: 0.82, green: 0.843, blue: 0.863), width: 1)
      .cornerRadius(8)

      if let error = error {
        Text(error)
          .font(.caption)
          .foregroundColor(Color(red: 0.859, green: 0.149, blue: 0.149))
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
