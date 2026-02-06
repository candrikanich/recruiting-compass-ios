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

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(Color(red: 0.216, green: 0.263, blue: 0.322))

      HStack(spacing: 12) {
        Image(systemName: icon)
          .foregroundColor(Color(red: 0.627, green: 0.655, blue: 0.686))
          .frame(width: 20)

        if isSecure {
          SecureField(placeholder, text: $text)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(onBlur)
        } else {
          TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(onBlur)
        }
      }
      .padding(12)
      .background(Color.white)
      .border(error != nil ? Color.red : Color(red: 0.82, green: 0.843, blue: 0.863), width: 1)
      .cornerRadius(8)

      if let error = error {
        Text(error)
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(Color(red: 0.859, green: 0.149, blue: 0.149))
      }
    }
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
