import SwiftUI

struct InteractionsListView: View {
  var body: some View {
    PlaceholderListView(
      title: "Interactions",
      message: "Interactions list coming soon",
      header: "Your interactions will appear here"
    )
  }
}

#Preview {
  NavigationStack {
    InteractionsListView()
  }
}
