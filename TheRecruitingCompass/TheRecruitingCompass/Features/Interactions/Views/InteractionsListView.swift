import SwiftUI

struct InteractionsListView: View {
  var body: some View {
    List {
      Section {
        Text("Interactions list coming soon")
          .font(.body)
          .foregroundColor(Color.secondaryText)
      } header: {
        Text("Your interactions will appear here")
          .font(.caption)
      }
    }
    .navigationTitle("Interactions")
    .navigationBarTitleDisplayMode(.large)
  }
}

#Preview {
  NavigationStack {
    InteractionsListView()
  }
}
