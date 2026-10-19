import SwiftUI

struct FamilyManagementView: View {
  @State private var viewModel = FamilyManagementViewModel()
  @Environment(AuthManager.self) private var authManager
  @Environment(FamilyManager.self) private var familyManager

  var body: some View {
    contentView
      .navigationTitle("Family Management")
      .navigationBarTitleDisplayMode(.large)
      .task {
        viewModel.onMembershipChanged = { await familyManager.loadFamilyData() }
        await viewModel.loadData()
      }
      .refreshable {
        await viewModel.loadData()
      }
      .alert("Error", isPresented: Binding(
        get: { viewModel.errorMessage != nil },
        set: { if !$0 { viewModel.clearError() } }
      )) {
      } message: {
        if let error = viewModel.errorMessage {
          Text(error)
        }
      }
      .confirmationDialog(
        "Remove Family Member",
        isPresented: $viewModel.showDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Remove", role: .destructive) {
          Task { await viewModel.removeMember() }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        if let member = viewModel.memberToRemove,
           let name = member.user?.fullName ?? member.user?.email {
          Text("Remove \(name) from family?")
        }
      }
      .confirmationDialog(
        "Leave Family",
        isPresented: $viewModel.showLeaveConfirmation,
        titleVisibility: .visible
      ) {
        Button("Leave Family", role: .destructive) {
          Task { await viewModel.leaveFamily() }
        }
        Button("Cancel", role: .cancel) { viewModel.cancelLeave() }
      } message: {
        Text("You'll lose access to this family's recruiting data.")
      }
      .confirmationDialog(
        "Delete Family?",
        isPresented: $viewModel.showLastMemberConfirmation,
        titleVisibility: .visible
      ) {
        Button("Leave and Delete Family", role: .destructive) {
          Task { await viewModel.leaveFamily(confirmDeleteFamily: true) }
        }
        Button("Cancel", role: .cancel) { viewModel.cancelLeave() }
      } message: {
        Text(viewModel.lastMemberLeaveWarning ?? "Leaving deletes the family and all of its data.")
      }
      .toast(
        isShowing: $viewModel.showSuccessToast,
        message: $viewModel.successMessage,
        type: .success,
        duration: 3.0
      )
  }

  // MARK: - Content View
  @ViewBuilder
  private var contentView: some View {
    if viewModel.isLoading && viewModel.familyCode == nil && viewModel.parentFamilies.isEmpty {
      LoadingStateView(message: "Loading family data...")
    } else {
      roleBasedView
    }
  }

  @ViewBuilder
  private var roleBasedView: some View {
    if viewModel.isPlayer {
      FamilyManagementPlayerView(viewModel: viewModel)
    } else if viewModel.isParent {
      FamilyManagementParentView(viewModel: viewModel)
    } else {
      unsupportedRoleView
    }
  }

  @ViewBuilder
  private var unsupportedRoleView: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      Image(systemName: "exclamationmark.triangle")
        .font(.brand(.largeTitle))
        .foregroundStyle(.orange)
        .accessibilityHidden(true)
      Text("Family Management Unavailable")
        .font(.brand(.headline))
      Text("This feature is only available for players and parents.")
        .font(.brand(.subheadline))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, FamilyConstants.Spacing.extraLarge)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Preview
#Preview {
  NavigationStack {
    FamilyManagementView()
  }
  .environment(AuthManager.shared)
  .environment(FamilyManager.shared)
}
