import SwiftUI

struct SuccessToast: View {
  let message: String

  var body: some View {
    Text(message)
      .font(.subheadline)
      .fontWeight(.medium)
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(Color.successGreen)
      .clipShape(Capsule())
      .shadow(radius: 4)
      .padding(.bottom, 20)
      .accessibilityLabel(message)
  }
}
