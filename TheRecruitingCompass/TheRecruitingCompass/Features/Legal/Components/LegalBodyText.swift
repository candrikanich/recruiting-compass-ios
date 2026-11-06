import SwiftUI

struct LegalBodyText: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.brand(.body))
      .foregroundStyle(Color.secondaryText)
      .fixedSize(horizontal: false, vertical: true)
  }
}
