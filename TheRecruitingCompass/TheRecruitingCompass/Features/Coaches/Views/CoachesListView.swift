import SwiftUI

struct CoachesListView: View {
  var body: some View {
    List {
      Section {
        Text("Coaches list coming soon")
          .font(.body)
          .foregroundColor(Color.secondaryText)
      } header: {
        Text("Your coaches will appear here")
          .font(.caption)
      }
    }
    .navigationTitle("Coaches")
    .navigationBarTitleDisplayMode(.large)
  }
}

#Preview {
  NavigationStack {
    CoachesListView()
  }
}
