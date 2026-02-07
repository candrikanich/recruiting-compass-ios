import SwiftUI

struct TermsCheckbox: View {
  @Binding var isChecked: Bool
  let onTermsPressed: () -> Void
  @Environment(\.sizeCategory) var sizeCategory

  private var checkboxSize: CGFloat {
    sizeCategory >= .extraLarge ? 20 : 18
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Button(action: { isChecked.toggle() }) {
          Image(systemName: isChecked ? "checkmark.square.fill" : "square")
            .font(.system(size: checkboxSize))
            .foregroundColor(
              isChecked
                ? Color(red: 0.149, green: 0.388, blue: 0.931)
                : Color(red: 0.627, green: 0.655, blue: 0.686)
            )
            .accessibilityHidden(true)
        }
        .accessibilityLabel("I agree to the Terms of Service and Privacy Policy")
        .accessibilityValue(isChecked ? "Checked" : "Unchecked")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to toggle agreement")

        HStack(spacing: 4) {
          Text("I agree to the")
            .font(.footnote)
            .foregroundColor(Color(red: 0.282, green: 0.337, blue: 0.431))
            .accessibilityHidden(true)

          Button(action: onTermsPressed) {
            Text("Terms of Service")
              .font(.footnote.weight(.semibold))
              .foregroundColor(Color(red: 0.149, green: 0.388, blue: 0.931))
              .underline()
          }
          .accessibilityLabel("Read Terms of Service")
          .accessibilityHint("Opens Terms of Service")

          Text("and")
            .font(.footnote)
            .foregroundColor(Color(red: 0.282, green: 0.337, blue: 0.431))
            .accessibilityHidden(true)

          Button(action: onTermsPressed) {
            Text("Privacy Policy")
              .font(.footnote.weight(.semibold))
              .foregroundColor(Color(red: 0.149, green: 0.388, blue: 0.931))
              .underline()
          }
          .accessibilityLabel("Read Privacy Policy")
          .accessibilityHint("Opens Privacy Policy")
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
