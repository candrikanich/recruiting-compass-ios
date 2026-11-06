import SwiftUI

struct LegalSectionHeader: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.brand(.headline))
      .foregroundStyle(Color.darkSlate)
      .accessibilityAddTraits(.isHeader)
  }
}
