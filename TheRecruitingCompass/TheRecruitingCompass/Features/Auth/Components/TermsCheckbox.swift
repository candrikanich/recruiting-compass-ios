import SwiftUI

struct TermsCheckbox: View {
  @Binding var isChecked: Bool
  let onTermsPressed: () -> Void
  let onPrivacyPressed: () -> Void
  @Environment(\.sizeCategory) var sizeCategory

  private var checkboxSize: CGFloat {
    sizeCategory >= .extraLarge ? 20 : 18
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Button(action: { isChecked.toggle() }) {
        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
          .font(.system(size: checkboxSize))
          .foregroundColor(
            isChecked
              ? Color.accentBlue
              : Color.iconGray
          )
          .accessibilityHidden(true)
      }
      .accessibilityLabel("I agree to the Terms of Service and Privacy Policy")
      .accessibilityValue(isChecked ? "Checked" : "Unchecked")
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Double tap to toggle agreement")

      VStack(alignment: .leading, spacing: 4) {
        Text("I agree to the")
          .font(.footnote)
          .foregroundColor(Color.tertiaryText)

        HStack(spacing: 0) {
          Button(action: onTermsPressed) {
            Text("Terms of Service")
              .font(.footnote.weight(.semibold))
              .foregroundColor(Color.accentBlue)
              .underline()
          }
          .accessibilityLabel("Read Terms of Service")
          .accessibilityHint("Opens Terms of Service")

          Text(" and ")
            .font(.footnote)
            .foregroundColor(Color.tertiaryText)
            .accessibilityHidden(true)

          Button(action: onPrivacyPressed) {
            Text("Privacy Policy")
              .font(.footnote.weight(.semibold))
              .foregroundColor(Color.accentBlue)
              .underline()
          }
          .accessibilityLabel("Read Privacy Policy")
          .accessibilityHint("Opens Privacy Policy")
        }
      }

      Spacer(minLength: 0)
    }
    .frame(minHeight: 44)
  }
}

#Preview {
  @Previewable @State var isChecked = false

  return VStack {
    TermsCheckbox(
      isChecked: $isChecked,
      onTermsPressed: { },
      onPrivacyPressed: { }
    )

    Spacer()
  }
  .padding()
}
