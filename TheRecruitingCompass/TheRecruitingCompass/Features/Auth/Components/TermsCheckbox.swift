import SwiftUI

struct TermsCheckbox: View {
  @Binding var isChecked: Bool
  let onTermsPressed: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Button(action: { isChecked.toggle() }) {
          Image(systemName: isChecked ? "checkmark.square.fill" : "square")
            .font(.system(size: 18))
            .foregroundColor(
              isChecked
                ? Color(red: 0.149, green: 0.388, blue: 0.931)
                : Color(red: 0.627, green: 0.655, blue: 0.686)
            )
        }

        HStack(spacing: 4) {
          Text("I agree to the")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(Color(red: 0.282, green: 0.337, blue: 0.431))

          Button(action: onTermsPressed) {
            Text("Terms of Service")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(Color(red: 0.149, green: 0.388, blue: 0.931))
              .underline()
          }

          Text("and")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(Color(red: 0.282, green: 0.337, blue: 0.431))

          Button(action: onTermsPressed) {
            Text("Privacy Policy")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(Color(red: 0.149, green: 0.388, blue: 0.931))
              .underline()
          }
        }

        Spacer()
      }
      .frame(minHeight: 44)
    }
  }
}

#Preview {
  @State var isChecked = false

  return VStack {
    TermsCheckbox(
      isChecked: $isChecked,
      onTermsPressed: {
        print("Terms pressed")
      }
    )

    Spacer()
  }
  .padding()
}
