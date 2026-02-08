import SwiftUI

struct OffersListView: View {
  var body: some View {
    List {
      Section {
        Text("Offers list coming soon")
          .font(.body)
          .foregroundColor(Color.secondaryText)
      } header: {
        Text("Your offers will appear here")
          .font(.caption)
      }
    }
    .navigationTitle("Offers")
    .navigationBarTitleDisplayMode(.large)
  }
}

#Preview {
  NavigationStack {
    OffersListView()
  }
}
