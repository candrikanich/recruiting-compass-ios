import SwiftUI

struct EmptyDashboardState: View {
  let onAddSchool: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 72 : 60
  }

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "location.fill")
        .font(.system(size: iconSize))
        .foregroundStyle(Color.primaryGreen)
        .accessibilityHidden(true)

      Text("Start Your Recruiting Journey")
        .font(.title2)
        .bold()
        .accessibilityAddTraits(.isHeader)

      Text("Add your first school to begin tracking your recruiting journey")
        .font(.body)
        .foregroundStyle(Color.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      Button(action: onAddSchool) {
        Text("Add Your First School")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal)
      .accessibilityLabel(String(localized: "Add your first school"))
      .accessibilityHint("Opens the form to add a school")
    }
    .padding()
  }
}

#Preview {
  EmptyDashboardState(onAddSchool: {})
}
