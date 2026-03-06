import SwiftUI

struct PlayerDetailsView: View {
    @State private var viewModel: PlayerDetailsViewModel

    init(preferenceService: any PreferenceManaging, userRole: UserRole) {
        _viewModel = State(initialValue: PlayerDetailsViewModel(
            preferenceService: preferenceService,
            userRole: userRole
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            PlayerCompletenessCard(score: viewModel.completenessScore)
                .padding(.horizontal)
                .padding(.top, 8)

            TabView(selection: $viewModel.selectedTab) {
                BasicsTab(viewModel: viewModel)
                    .tabItem { Label("Basics", systemImage: "person.crop.square") }
                    .tag(0)

                AthleticsTab(viewModel: viewModel)
                    .tabItem { Label("Athletics", systemImage: "bolt.fill") }
                    .tag(1)

                AcademicsSocialTab(viewModel: viewModel)
                    .tabItem { Label("Academics", systemImage: "graduationcap.fill") }
                    .tag(2)

                HistoryTab(viewModel: viewModel)
                    .tabItem { Label("History", systemImage: "clock.fill") }
                    .tag(3)
            }
            .onChange(of: viewModel.selectedTab) { _, _ in
                viewModel.triggerFitScoreRecalculation()
            }
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Player Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SaveStatusView(status: viewModel.saveStatus)
            }
        }
        .overlay {
            PreferenceLoadingOverlay(
                isLoading: viewModel.isLoading,
                message: "Loading details..."
            )
        }
        .preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
        .alert("Delete Profile Photo?", isPresented: $viewModel.showDeletePhotoConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteProfilePhoto() }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .task {
            await viewModel.loadDetails()
        }
        .onDisappear {
            viewModel.triggerFitScoreRecalculation()
        }
    }
}

struct PlayerDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PlayerDetailsView(
                preferenceService: PreferencePreviewMock(defaultValue: PlayerDetails.default),
                userRole: .player
            )
        }
    }
}
