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

            tabSelector

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

    /// Horizontally scrollable segment control. Replaces `.pickerStyle(.segmented)`, which
    /// truncates the 9-char labels ("Academics"/"Athletics") to "Academ…" on narrow devices
    /// once there are five segments. Scrolling keeps every label fully readable at any width.
    @ViewBuilder
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(Self.tabTitles.enumerated()), id: \.offset) { index, title in
                    let isSelected = viewModel.selectedTab == index
                    Button {
                        viewModel.selectedTab = index
                    } label: {
                        Text(title)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                Capsule().fill(
                                    isSelected ? Color.accentColor : Color(.tertiarySystemBackground)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(title))
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .onChange(of: viewModel.selectedTab) { _, _ in
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
