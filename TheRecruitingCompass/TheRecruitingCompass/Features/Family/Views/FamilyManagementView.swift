import SwiftUI

struct FamilyManagementView: View {
  @StateObject private var viewModel = FamilyManagementViewModel()
  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    contentView
      .navigationTitle("Family Management")
      .navigationBarTitleDisplayMode(.large)
      .task {
        await viewModel.loadData()
      }
      .refreshable {
        await viewModel.loadData()
      }
      .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
        Button("OK") { viewModel.clearError() }
      } message: {
        if let error = viewModel.errorMessage {
          Text(error)
        }
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

  private var unsupportedRoleView: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundColor(.orange)
        .accessibilityHidden(true)
      Text("Family Management Unavailable")
        .font(.headline)
      Text("This feature is only available for players and parents.")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, FamilyConstants.Spacing.extraLarge)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Preview
#if DEBUG
struct FamilyManagementView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      FamilyManagementView()
        .environmentObject(AuthManager.shared)
    }
  }
}
#endif
