import SwiftUI
import UIKit

/// Editor + live-preview container for the "Public Profile" segment of Player Profile.
/// Owns its own `PublicProfileViewModel`, scoped to the shared `PlayerDetailsViewModel`'s
/// athlete context (`targetUserId`/`familyUnitId`), and re-assembles the coach-facing
/// `PublicProfileCard` preview whenever an editor control commits a change.
///
/// Structure mirrors web `ProfileSetup.vue` (Figma parity, PRs #507–509): workspace bar,
/// Share card (custom URL folded in), Appearance, Content, Section Configuration
/// (reorder + eye toggle), Recruitment Status, then a live preview + QR code.
struct PublicTab: View {
    @State private var vm: PublicProfileViewModel
    @State private var bioSaveTask: Task<Void, Never>?
    @State private var lookingForSaveTask: Task<Void, Never>?
    @State private var exportedPDF: ExportedProfilePDF?
    @State private var isExporting = false
    @State private var isShowingShareSheet = false
    @State private var newValueTag = ""
    @State private var newAwardTitle = ""
    @State private var newAwardYear = ""

    private let bioCharacterLimit = 300
    private let lookingForCharacterLimit = 600

    init(viewModel: PlayerDetailsViewModel) {
        self.init(targetUserId: viewModel.publicTargetUserId)
    }

    /// Standalone entry point (Dashboard card, More menu) — reachable without a
    /// `PlayerDetailsViewModel`, scoped to `targetUserId` (nil = current user).
    init(targetUserId: String?) {
        _vm = State(initialValue: PublicProfileViewModel(
            service: PublicProfileServiceImpl(),
            authManager: AuthManager.shared,
            targetUserId: targetUserId,
            familyUnitId: FamilyManager.shared.familyUnitId
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !vm.isConfigured {
                    unconfiguredNotice
                } else {
                    workspaceBar
                    shareCard
                    appearanceCard
                    contentCard
                    sectionConfigCard
                    recruitmentStatusCard

                    if let saveError = vm.saveError {
                        Text(saveError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel(Text(saveError))
                    }

                    livePreview
                }
            }
            .padding()
        }
        .task {
            await vm.load()
            await vm.assembleCard()
        }
        .sheet(item: $exportedPDF) { pdf in
            ActivityShareSheet(activityItems: [pdf.url])
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let shareURL = vm.shareURL {
                ActivityShareSheet(activityItems: [shareURL])
            }
        }
    }

    // MARK: - Workspace bar

    @ViewBuilder
    private var workspaceBar: some View {
        HStack {
            Label(String(localized: "RecruitingCompass Workspace"), systemImage: "viewfinder.circle")
                .font(.subheadline.weight(.semibold))
            Spacer()
            HStack(spacing: 8) {
                statusPill
                Toggle("", isOn: $vm.isPublished)
                    .labelsHidden()
                    .onChange(of: vm.isPublished) { _, _ in commit() }
                    .accessibilityLabel(String(localized: "Publish public profile"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusPill: some View {
        Text(vm.isPublished
             ? String(localized: "Your profile is live & public")
             : String(localized: "Not published"))
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(vm.isPublished ? Color.green.opacity(0.15) : Color.Surface.muted)
        .foregroundStyle(vm.isPublished ? .green : Color.Text.muted)
        .clipShape(Capsule())
    }

    // MARK: - Share card (custom URL folded in per PR #509)

    @ViewBuilder
    private var shareCard: some View {
        boxedCard(title: String(localized: "Share Profile Link")) {
            ShareLinkRow(url: vm.shareURL) {
                UIPasteboard.general.string = vm.shareURL?.absoluteString
            }
            Button {
                isShowingShareSheet = true
            } label: {
                Label(String(localized: "Share Profile"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(vm.shareURL == nil)

            Divider()
            vanitySlugField
        }
    }

    @ViewBuilder
    private var vanitySlugField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Custom URL (optional)"))
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

    // MARK: - 1. Appearance Settings

    @ViewBuilder
    private var appearanceCard: some View {
        boxedCard(title: String(localized: "1. Appearance Settings")) {
            Text(String(localized: "Hero Background Color Theme"))
                .font(.subheadline)
            HeaderColorPicker(selection: $vm.headerColor)
                .onChange(of: vm.headerColor) { _, _ in commit() }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label(String(localized: "Upload Custom Banner"), systemImage: "photo")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.Text.muted)
                Text(String(localized: "Recommended: 1200×400 JPG or PNG"))
                    .font(.caption2)
                    .foregroundStyle(Color.Text.muted)
                // Parity note: web doesn't render the banner on the public hero yet
                // either (§7 of the handoff spec) — this control round-trips
                // `banner_url` for when that lands, but has no upload flow yet.
            }
        }
    }

    // MARK: - 2. Profile Content — Bio → Looking For → Values → Awards

    @ViewBuilder
    private var contentCard: some View {
        boxedCard(title: String(localized: "2. Profile Content")) {
            bioField
            Divider()
            lookingForField
            Divider()
            valuesTagsEditor
            Divider()
            awardsEditor
        }
    }

    @ViewBuilder
    private var bioField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Bio"))
                .font(.subheadline)
            TextEditor(text: $vm.bio)
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.Surface.border, lineWidth: 1))
                .onChange(of: vm.bio) { _, newValue in
                    if newValue.count > bioCharacterLimit {
                        vm.bio = String(newValue.prefix(bioCharacterLimit))
                    }
                    scheduleDebouncedSave(&bioSaveTask)
                }
            Text("\(vm.bio.count)/\(bioCharacterLimit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var lookingForField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "What I'm Looking For"))
                .font(.subheadline)
            TextEditor(text: $vm.lookingFor)
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.Surface.border, lineWidth: 1))
                .onChange(of: vm.lookingFor) { _, newValue in
                    if newValue.count > lookingForCharacterLimit {
                        vm.lookingFor = String(newValue.prefix(lookingForCharacterLimit))
                    }
                    scheduleDebouncedSave(&lookingForSaveTask)
                }
            Text("\(vm.lookingFor.count)/\(lookingForCharacterLimit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var valuesTagsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Values"))
                .font(.subheadline)
            if !vm.valuesTags.isEmpty {
                FlowChips(chips: vm.valuesTags.map { "\($0)  ×" })
                    // Tap targets: a chip-per-tag remove list, mirroring web's
                    // removable-tag chips without a custom wrapping Layout.
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(vm.valuesTags, id: \.self) { tag in
                        HStack {
                            Text(tag).font(.footnote)
                            Spacer()
                            Button {
                                vm.removeValueTag(tag)
                                commit()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .accessibilityLabel(String(localized: "Remove \(tag)"))
                        }
                    }
                }
            }
            HStack {
                TextField(String(localized: "Add a value (e.g. Academics, Faith)"), text: $newValueTag)
                    .textFieldStyle(.roundedBorder)
                Button(String(localized: "Add")) {
                    vm.addValueTag(newValueTag)
                    newValueTag = ""
                    commit()
                }
                .disabled(newValueTag.trimmingCharacters(in: .whitespaces).isEmpty || vm.valuesTags.count >= 12)
            }
            Text(String(localized: "\(vm.valuesTags.count)/12"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var awardsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Awards"))
                .font(.subheadline)
            ForEach(vm.awards) { award in
                HStack {
                    Text(award.year.map { "\(award.title) · \($0)" } ?? award.title)
                        .font(.footnote)
                    Spacer()
                    Button {
                        vm.removeAward(award)
                        commit()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .accessibilityLabel(String(localized: "Remove \(award.title)"))
                }
            }
            HStack {
                TextField(String(localized: "Award title"), text: $newAwardTitle)
                    .textFieldStyle(.roundedBorder)
                TextField(String(localized: "Year"), text: $newAwardYear)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                Button(String(localized: "Add")) {
                    vm.addAward(title: newAwardTitle, year: Int(newAwardYear))
                    newAwardTitle = ""
                    newAwardYear = ""
                    commit()
                }
                .disabled(newAwardTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - 3. Section Configuration (reorder + eye toggle)

    @ViewBuilder
    private var sectionConfigCard: some View {
        boxedCard(title: String(localized: "3. Section Configuration")) {
            VStack(spacing: 8) {
                ForEach(Array(vm.sections.enumerated()), id: \.element.key) { index, section in
                    sectionConfigRow(section, index: index)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionConfigRow(_ section: ProfileSection, index: Int) -> some View {
        HStack {
            VStack(spacing: 2) {
                Button {
                    guard index > 0 else { return }
                    vm.moveSections(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
                    commit()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(index == 0)
                Button {
                    guard index < vm.sections.count - 1 else { return }
                    vm.moveSections(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
                    commit()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(index == vm.sections.count - 1)
            }
            .font(.caption)
            .accessibilityLabel(String(localized: "Reorder \(section.key.label)"))

            Text(section.key.label)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                vm.toggleSectionVisibility(section.key)
                commit()
            } label: {
                Image(systemName: section.visible ? "eye" : "eye.slash")
            }
            .accessibilityLabel(String(localized: section.visible ? "Hide \(section.key.label)" : "Show \(section.key.label)"))
        }
        .padding(10)
        .background(Color.Surface.muted.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 4. Recruitment Status

    @ViewBuilder
    private var recruitmentStatusCard: some View {
        boxedCard(title: String(localized: "4. Recruitment Status")) {
            Picker(String(localized: "Commitment Status"), selection: $vm.commitmentStatus) {
                ForEach(CommitmentStatus.allCases, id: \.self) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.commitmentStatus) { _, _ in commit() }

            Text(String(localized: "Updating this adds a status tag to your live page"))
                .font(.caption)
                .foregroundStyle(Color.Text.muted)

            if vm.commitmentStatus == .committed {
                Picker(String(localized: "Committed School"), selection: $vm.committedSchoolId) {
                    Text(String(localized: "Select a school")).tag(String?.none)
                    ForEach(vm.availableSchools) { school in
                        Text(school.name).tag(Optional(school.id))
                    }
                }
                .onChange(of: vm.committedSchoolId) { _, _ in commit() }
            }
        }
    }

    // MARK: - Live Preview

    @ViewBuilder
    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "What coaches see"))
                .font(.headline)
            if let card = vm.cardData {
                PublicProfileCard(data: card)
                downloadPDFButton(card: card)
            }
            if let shareURL = vm.shareURL {
                ProfileQRCodeView(url: shareURL)
            }
        }
    }

    @ViewBuilder
    private func downloadPDFButton(card: PublicProfileData) -> some View {
        Button {
            exportPDF(card: card)
        } label: {
            HStack(spacing: 8) {
                if isExporting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.down.doc").accessibilityHidden(true)
                }
                Text(String(localized: "Download as PDF"))
                    .font(.callout.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(isExporting)
        .accessibilityLabel(String(localized: "Download profile as PDF"))
        .accessibilityHint(String(localized: "Creates a PDF of your public profile to share"))
    }

    private func exportPDF(card: PublicProfileData) {
        isExporting = true
        Task {
            defer { isExporting = false }
            guard let data = await PublicProfilePDFRenderer.renderWithPhoto(card) else { return }
            let filename = PublicProfilePDFRenderer.filename(for: card.playerName)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: url)
                exportedPDF = ExportedProfilePDF(url: url)
            } catch {
                // Non-fatal: leave the sheet unpresented if the temp write fails.
            }
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
    private func boxedCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func commit() {
        Task {
            await vm.save()
            await vm.assembleCard()
        }
    }

    /// Debounced auto-save, since `TextEditor` has no reliable commit event
    /// (`.onSubmit` never fires for multi-line text) and would otherwise lose
    /// edits unless another control happens to be touched afterward.
    private func scheduleDebouncedSave(_ task: inout Task<Void, Never>?) {
        task?.cancel()
        let capturedVM = vm
        task = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            await capturedVM.save()
            await capturedVM.assembleCard()
        }
    }
}

/// Wraps the exported PDF's temp-file URL so it can drive a `.sheet(item:)`.
private struct ExportedProfilePDF: Identifiable {
    let id = UUID()
    let url: URL
}
