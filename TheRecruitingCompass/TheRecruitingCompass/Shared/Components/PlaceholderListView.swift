import SwiftUI

struct PlaceholderListView: View {
  let title: String
  let message: String
  let header: String

  var body: some View {
    List {
      Section {
        Text(message)
          .font(.body)
          .foregroundStyle(Color.secondaryText)
      } header: {
        Text(header)
          .font(.caption)
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.large)
  }
}

#Preview {
  NavigationStack {
    PlaceholderListView(
      title: "Schools",
      message: "Schools list coming soon",
      header: "Your schools will appear here"
    )
  }
}
