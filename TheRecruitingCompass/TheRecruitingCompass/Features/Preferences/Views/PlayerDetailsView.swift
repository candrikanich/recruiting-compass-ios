import SwiftUI

struct PlayerDetailsView: View {
    @State private var viewModel: PlayerDetailsViewModel

    init(preferenceService: any PreferenceManaging, userRole: UserRole, targetUserId: String? = nil) {
        _viewModel = State(initialValue: PlayerDetailsViewModel(
            preferenceService: preferenceService,
            userRole: userRole,
            targetUserId: targetUserId
        ))
    }

    private static let tabTitles = [
        String(localized: "Basics"),
        String(localized: "Athletics"),
        String(localized: "Academics"),
        String(localized: "History"),
        String(localized: "Public")
    ]

    var body: some View {
        VStack(spacing: 0) {
            PlayerCompletenessCard(score: viewModel.completenessScore)
                .padding(.horizontal)
                .padding(.top, 8)

            Picker("Section", selection: $viewModel.selectedTab) {
                ForEach(Array(Self.tabTitles.enumerated()), id: \.offset) { index, title in
                    Text(title).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: viewModel.selectedTab) { _, _ in
                viewModel.triggerFitScoreRecalculation()
            }

            tabContent
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
                message: String(localized: "Loading details...")
            )
        }
        .preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
        .sensoryFeedback(.success, trigger: viewModel.hapticSuccessTrigger)
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

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case 1:  AthleticsTab(viewModel: viewModel)
        case 2:  AcademicsSocialTab(viewModel: viewModel)
        case 3:  HistoryTab(viewModel: viewModel)
        case 4:  PublicTab(viewModel: viewModel)
        default: BasicsTab(viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        PlayerDetailsView(
            preferenceService: PreferencePreviewMock(defaultValue: PlayerDetails.default),
            userRole: .player
        )
    }
}
