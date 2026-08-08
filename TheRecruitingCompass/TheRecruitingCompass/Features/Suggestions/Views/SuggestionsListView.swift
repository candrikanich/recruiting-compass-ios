import SwiftUI

struct SuggestionsListView: View {
  var viewModel: DashboardViewModel

  var body: some View {
    List {
      if let errorMessage = viewModel.suggestionsError {
        ErrorBanner(message: errorMessage) { viewModel.suggestionsError = nil }
          .listRowSeparator(.hidden)
      }

      if viewModel.isSuggestionsLoading && viewModel.suggestions.isEmpty {
        LoadingStateView(message: "Loading action items…")
          .frame(maxWidth: .infinity)
          .listRowSeparator(.hidden)
      } else if viewModel.suggestions.isEmpty {
        if viewModel.suggestionsError == nil {
          ContentUnavailableView(
            "No Action Items",
            systemImage: "checkmark.circle",
            description: Text("You're all caught up! Check back later for new suggestions.")
          )
        }
      } else {
        ForEach(viewModel.suggestions) { suggestion in
          ActionItemCard(
            suggestion: suggestion,
            familyUnitId: viewModel.currentFamilyUnitId,
            userId: viewModel.actingUserId,
            onDismiss: { Task { await viewModel.dismissSuggestion(suggestion.id) } },
            onComplete: { Task { await viewModel.completeSuggestion(suggestion.id) } },
            onActionCompleted: { Task { await viewModel.fetchSuggestions() } }
          )
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowSeparator(.hidden)
        }
      }
    }
    .listStyle(.plain)
    .navigationTitle("Action Items")
    .navigationBarTitleDisplayMode(.large)
    .refreshable {
      await viewModel.fetchSuggestions()
    }
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
