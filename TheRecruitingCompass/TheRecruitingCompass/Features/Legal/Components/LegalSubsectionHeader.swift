import SwiftUI

struct LegalSubsectionHeader: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Color.darkSlate)
      .accessibilityAddTraits(.isHeader)
  }
}
