import SwiftUI

struct OffersListView: View {
  var body: some View {
    PlaceholderListView(
      title: "Offers",
      message: "Offers list coming soon",
      header: "Your offers will appear here"
    )
  }
}

#Preview {
  NavigationStack {
    OffersListView()
  }
}
