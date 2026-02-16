import SwiftUI

struct EmptyDashboardState: View {
  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 72 : 60
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "location.fill")
        .font(.system(size: iconSize))
        .foregroundColor(Color.primaryGreen)
        .accessibilityHidden(true)

      Text("Start Your Recruiting Journey")
        .font(.title2)
        .fontWeight(.bold)
        .accessibilityAddTraits(.isHeader)

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
