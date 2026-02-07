import SwiftUI

struct TimeoutBanner: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "hourglass")
        .foregroundColor(Color.warningOrange)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text("You were logged out due to inactivity. Please log in again.")
          .font(.footnote)
          .foregroundColor(Color.warningOrange)
      }

      Spacer()
    }
    .padding(12)
    .background(Color.warningBackground)
    .border(Color.warningBorder, width: 1)
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Session timeout warning")
    .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  TimeoutBanner()
    .padding()
}
