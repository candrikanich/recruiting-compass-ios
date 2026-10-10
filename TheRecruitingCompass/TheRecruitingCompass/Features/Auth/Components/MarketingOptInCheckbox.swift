import SwiftUI

/// Optional, unchecked-by-default marketing email consent (web #1066). Callers render it only
/// for marketing-eligible adults — see `MarketingEligibility`.
struct MarketingOptInCheckbox: View {
  @Binding var isChecked: Bool
  @ScaledMetric(relativeTo: .body) private var checkboxSize: CGFloat = 18

  var body: some View {
    Button {
      isChecked.toggle()
    } label: {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
          .font(.system(size: checkboxSize))
          .foregroundStyle(isChecked ? Color.accentPrimary : Color.iconGray)
          .accessibilityHidden(true)

        Text(Self.copy)
          .font(.footnote)
          .foregroundStyle(Color.tertiaryText)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)

        Spacer(minLength: 0)
      }
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.copy)
    .accessibilityValue(isChecked ? String(localized: "Checked") : String(localized: "Unchecked"))
    .accessibilityAddTraits(.isButton)
    .accessibilityHint(String(localized: "Double tap to toggle marketing emails"))
    .accessibilityIdentifier("marketingOptInCheckbox")
  }

  private static let copy = String(
    localized: """
      Send me recruiting tips, product updates and offers from The Recruiting Compass. \
      You can unsubscribe anytime.
      """
  )
}

#Preview {
  @Previewable @State var isChecked = false

  return VStack {
    MarketingOptInCheckbox(isChecked: $isChecked)
    Spacer()
  }
  .padding()
}
