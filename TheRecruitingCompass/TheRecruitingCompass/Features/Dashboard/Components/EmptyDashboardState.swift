import SwiftUI

struct EmptyDashboardState: View {
  let onAddSchool: () -> Void

  var body: some View {
    EmptyStateView(
      icon: "location.fill",
      title: String(localized: "Start Your Recruiting Journey"),
      message: String(localized: "Add your first school to begin tracking your recruiting journey"),
      actionTitle: String(localized: "Add Your First School"),
      actionHint: String(localized: "Opens the form to add a school"),
      action: onAddSchool
    )
  }
}

#Preview {
  EmptyDashboardState(onAddSchool: {})
}
