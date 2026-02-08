import SwiftUI

struct EmptyDashboardState: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "location.fill")
        .font(.system(size: 60))
        .foregroundColor(Color.primaryGreen)
        .accessibilityHidden(true)

      Text("Start Your Recruiting Journey")
        .font(.title2)
        .fontWeight(.bold)

      Text("Add your first school or log an interaction to get started")
        .font(.body)
        .foregroundColor(Color.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    .padding()
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  EmptyDashboardState()
}
