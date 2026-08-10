import SwiftUI
import UIKit

/// Editor + live-preview container for the "Public Profile" segment of Player Profile.
/// Owns its own `PublicProfileViewModel`, scoped to the shared `PlayerDetailsViewModel`'s
/// athlete context (`targetUserId`/`familyUnitId`), and re-assembles the coach-facing
/// `PublicProfileCard` preview whenever an editor control commits a change.
struct PublicTab: View {
    let viewModel: PlayerDetailsViewModel
    @State private var vm: PublicProfileViewModel

    private let bioCharacterLimit = 300

    init(viewModel: PlayerDetailsViewModel) {
        self.viewModel = viewModel
        _vm = State(initialValue: PublicProfileViewModel(
            service: PublicProfileServiceImpl(),
            authManager: AuthManager.shared,
            targetUserId: viewModel.publicTargetUserId,
            familyUnitId: FamilyManager.shared.familyUnitId
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !vm.isConfigured {
                    unconfiguredNotice
                } else {
                    editor
                    Divider()
                    Text(String(localized: "What coaches see"))
                        .font(.headline)
                    if let card = vm.cardData {
                        PublicProfileCard(data: card)
                    }
                }
            }
            .padding()
        }
        .task {
            await vm.load()
            await vm.assembleCard()
        }
    }

    @ViewBuilder
    private var unconfiguredNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Public profile not available"))
                .font(.headline)
            Text(String(
                localized: "Set up your public profile on the web to share a coach-facing link."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(String(localized: "Publish public profile"), isOn: $vm.isPublished)
                .onChange(of: vm.isPublished) { _, _ in commit() }

            ShareLinkRow(url: vm.shareURL) {
                UIPasteboard.general.string = vm.shareURL?.absoluteString
            }

            vanitySlugField
            bioField

            Text(String(localized: "Header color"))
                .font(.subheadline)
            HeaderColorPicker(selection: $vm.headerColor)
                .onChange(of: vm.headerColor) { _, _ in commit() }

            Text(String(localized: "What to show coaches"))
                .font(.headline)

            Toggle(String(localized: "Academics"), isOn: $vm.showAcademics)
                .onChange(of: vm.showAcademics) { _, _ in commit() }
            Toggle(String(localized: "Athletic"), isOn: $vm.showAthletic)
                .onChange(of: vm.showAthletic) { _, _ in commit() }
            Toggle(String(localized: "Film"), isOn: $vm.showFilm)
                .onChange(of: vm.showFilm) { _, _ in commit() }
            Toggle(String(localized: "Schools"), isOn: $vm.showSchools)
                .onChange(of: vm.showSchools) { _, _ in commit() }
        }
    }

    @ViewBuilder
    private var vanitySlugField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Custom URL"))
                .font(.subheadline)
            TextField(String(localized: "your-name"), text: $vm.vanitySlug)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .onChange(of: vm.vanitySlug) { _, _ in vm.validateSlug() }
                .onSubmit { commit() }
            if let slugError = vm.slugError {
                Text(slugError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var bioField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Bio"))
                .font(.subheadline)
            TextEditor(text: $vm.bio)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.Surface.border, lineWidth: 1)
                )
                .onChange(of: vm.bio) { _, newValue in
                    if newValue.count > bioCharacterLimit {
                        vm.bio = String(newValue.prefix(bioCharacterLimit))
                    }
                }
                .onSubmit { commit() }
            Text("\(vm.bio.count)/\(bioCharacterLimit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func commit() {
        Task {
            await vm.save()
            await vm.assembleCard()
        }
    }
}
