import SwiftUI

struct SchoolsListView: View {
  var body: some View {
    List {
      Section {
        Text("Schools list coming soon")
          .font(.body)
          .foregroundColor(Color.secondaryText)
      } header: {
        Text("Your schools will appear here")
          .font(.caption)
      }
    }
    .navigationTitle("Schools")
    .navigationBarTitleDisplayMode(.large)
  }
}

#Preview {
  NavigationStack {
    SchoolsListView()
  }
}
