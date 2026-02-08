import SwiftUI

struct SchoolsListView: View {
  var body: some View {
    PlaceholderListView(
      title: "Schools",
      message: "Schools list coming soon",
      header: "Your schools will appear here"
    )
  }
}

#Preview {
  NavigationStack {
    SchoolsListView()
  }
}
