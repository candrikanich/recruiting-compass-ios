import SwiftUI

struct InteractionPrivacyNotice: View {
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "info.circle.fill")
        .font(.title3)
        .foregroundColor(.blue)
        .accessibilityHidden(true)

      Text("Your recruiting interactions are visible to your linked parent(s)")
        .font(.subheadline)
        .foregroundColor(.blue.opacity(0.9))
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
    .padding(12)
    .background(Color.blue.opacity(0.1))
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Privacy notice: Your recruiting interactions are visible to your linked parents")
  }
}

#Preview {
  InteractionPrivacyNotice()
    .padding()
}
