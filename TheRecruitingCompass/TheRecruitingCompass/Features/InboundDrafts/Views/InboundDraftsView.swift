import SwiftUI

/// Review queue for coach emails forwarded to the family's inbound address.
/// Reached from the More menu's "Coach Emails" row and from a notification tap
/// with `relatedEntityType == "inbound_email_draft"`.
struct InboundDraftsView: View {
  @State private var viewModel = InboundDraftsViewModel()

  var body: some View {
    contentView
      .navigationTitle("Coach Emails")
      .navigationBarTitleDisplayMode(.inline)
      .refreshable { await viewModel.loadDrafts() }
      .task { await viewModel.loadDrafts() }
      .toast(
        isShowing: $viewModel.showErrorToast,
        message: $viewModel.toastMessage,
        type: .error,
        duration: 4.0
      )
      .sheet(item: $viewModel.draftToReview) { draft in
        if let familyUnitId = viewModel.familyUnitId, let userId = viewModel.currentUserId {
          NavigationStack {
            AddInteractionView(
              interactionsService: InteractionsServiceImpl(supabaseManager: .shared),
              familyUnitId: familyUnitId,
              userId: userId,
              draftToConfirm: draft,
              onLogged: { _ in viewModel.handleDraftConfirmed(draft.id) }
            )
          }
        }
      }
      .accessibilityIdentifier("inbound_drafts_list")
  }

  @ViewBuilder
  private var contentView: some View {
    if viewModel.isLoading && viewModel.drafts.isEmpty {
      LoadingStateView(message: "Loading drafts...")
    } else if let errorMessage = viewModel.errorMessage, viewModel.drafts.isEmpty {
      ContentUnavailableView {
        Label("Couldn't load drafts", systemImage: "exclamationmark.triangle")
      } description: {
        Text(errorMessage)
      } actions: {
        Button("Retry") { Task { await viewModel.loadDrafts() } }
      }
    } else if viewModel.drafts.isEmpty {
      ContentUnavailableView {
        Label("No emails to review", systemImage: "tray")
      } description: {
        Text("Forward a coach's email to your family's forwarding address in Settings and it'll show up here.")
      }
    } else {
      draftList
    }
  }

  @ViewBuilder
  private var draftList: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(viewModel.drafts) { draft in
          InboundDraftCard(
            draft: draft,
            isPending: viewModel.pendingActionDraftIds.contains(draft.id),
            onConfirm: { viewModel.reviewDraft(draft) },
            onDiscard: { Task { await viewModel.discard(draft) } }
          )
        }
      }
      .padding(16)
    }
  }
}

#Preview {
  NavigationStack {
    InboundDraftsView()
  }
  .environment(AuthManager.shared)
  .environment(FamilyManager.shared)
}
