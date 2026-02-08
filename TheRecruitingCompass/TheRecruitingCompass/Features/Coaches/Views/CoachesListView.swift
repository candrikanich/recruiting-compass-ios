import SwiftUI

struct CoachesListView: View {
  var body: some View {
    PlaceholderListView(
      title: "Coaches",
      message: "Coaches list coming soon",
      header: "Your coaches will appear here"
    )
  }
}

#Preview {
  NavigationStack {
    CoachesListView()
  }
}
