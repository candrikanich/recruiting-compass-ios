import SwiftUI

struct SuggestionsListView: View {
  var viewModel: DashboardViewModel

  var body: some View {
    List {
      if viewModel.suggestions.isEmpty {
        ContentUnavailableView(
          "No Action Items",
          systemImage: "checkmark.circle",
          description: Text("You're all caught up! Check back later for new suggestions.")
        )
      } else {
        ForEach(viewModel.suggestions) { suggestion in
          ActionItemCard(
            suggestion: suggestion,
            onDismiss: {
              Task {
                await viewModel.dismissSuggestion(suggestion.id)
              }
            },
            onComplete: {
              Task {
                await viewModel.completeSuggestion(suggestion.id)
              }
            }
          )
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowSeparator(.hidden)
        }
      }
    }
    .listStyle(.plain)
    .navigationTitle("Action Items")
    .navigationBarTitleDisplayMode(.large)
  }
}

#Preview {
  NavigationStack {
    SuggestionsListView(viewModel: {
      let vm = DashboardViewModel()
      // Preview with mock data would go here
      return vm
    }())
  }
}
