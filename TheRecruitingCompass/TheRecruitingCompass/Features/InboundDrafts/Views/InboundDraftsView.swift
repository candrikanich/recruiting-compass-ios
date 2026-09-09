import SwiftUI

/// Review queue for coach emails forwarded to the family's inbound address.
/// Reached from the More menu's "Coach Emails" row and from a notification tap
/// with `relatedEntityType == "inbound_email_draft"`.
struct InboundDraftsView: View {
  @State private var viewModel = InboundDraftsViewModel()
  @State private var draftToConfirm: InboundEmailDraft?

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
      .accessibilityIdentifier("inbound_drafts_list")
      .sheet(item: $draftToConfirm) { draft in
        confirmSheet(for: draft)
      }
  }

  @ViewBuilder
  private func confirmSheet(for draft: InboundEmailDraft) -> some View {
    if let familyUnitId = viewModel.familyUnitId, let userId = viewModel.userId {
      NavigationStack {
        AddInteractionView(
          interactionsService: InteractionsServiceImpl(supabaseManager: .shared),
          familyUnitId: familyUnitId,
          userId: userId,
          initialFormState: InteractionFormState(fromDraft: draft),
          submitOverride: { formState in
            try await viewModel.confirm(draft, with: formState)
          }
        )
      }
    }
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

  private var draftList: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(viewModel.drafts) { draft in
          InboundDraftCard(
            draft: draft,
            isPending: viewModel.pendingActionDraftIds.contains(draft.id),
            onConfirm: { draftToConfirm = draft },
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
