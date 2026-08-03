import SwiftUI

struct PasswordFormField: View {
  let label: String
  let placeholder: String
  @Binding var text: String
  @Binding var error: String?
  @Binding var isPasswordVisible: Bool
  let onBlur: () -> Void
  @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 20

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.primary)
        .accessibilityHidden(true)

      HStack(spacing: 12) {
        Image(systemName: "lock")
          .foregroundStyle(Color.secondary)
          .frame(width: iconWidth)
          .accessibilityHidden(true)

        if isPasswordVisible {
          TextField(placeholder, text: $text)
            .foregroundStyle(Color.primary)
            .accessibilityLabel(label)
            .accessibilityValue(error.map { "Error: \($0)" } ?? "")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(onBlur)
        } else {
          SecureField(placeholder, text: $text)
            .foregroundStyle(Color.primary)
            .accessibilityLabel(label)
            .accessibilityValue(error.map { "Error: \($0)" } ?? "")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(onBlur)
        }

        Button(action: { isPasswordVisible.toggle() }) {
          Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
            .foregroundStyle(Color.secondary)
            .frame(width: iconWidth)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
        .accessibilityHint("Toggle to \(isPasswordVisible ? "hide" : "show") password characters")
      }
      .padding(12)
      .background(Color(uiColor: .secondarySystemBackground))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(error != nil ? Color.red : Color(uiColor: .separator), lineWidth: 1)
      )
      .clipShape(.rect(cornerRadius: 8))

      if let error = error {
        Text(error)
          .font(.caption)
          .foregroundStyle(Color.errorRed)
          .accessibilityLabel("Error: \(error)")
      }
    }
    .accessibilityElement(children: .contain)
  }
}

#Preview {
  @Previewable @State var text = ""
  @Previewable @State var error: String?
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
