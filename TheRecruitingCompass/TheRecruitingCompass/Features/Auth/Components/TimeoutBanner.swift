import SwiftUI

struct TimeoutBanner: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "hourglass")
        .foregroundColor(Color(red: 0.576, green: 0.25, blue: 0.056))

      VStack(alignment: .leading, spacing: 2) {
        Text("You were logged out due to inactivity. Please log in again.")
          .font(.system(size: 14, weight: .regular))
          .foregroundColor(Color(red: 0.576, green: 0.25, blue: 0.056))
      }

      Spacer()
    }
    .padding(12)
    .background(Color(red: 1, green: 0.984, blue: 0.92))
    .border(Color(red: 0.996, green: 0.891, blue: 0.658), width: 1)
    .cornerRadius(8)
  }
}

#Preview {
  TimeoutBanner()
    .padding()
}
