import SwiftUI
import PhotosUI

struct BasicsTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let sports = [
        "Baseball", "Softball", "Basketball", "Football", "Soccer",
        "Volleyball", "Tennis", "Swimming", "Track & Field", "Lacrosse", "Other"
    ]

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                cardSection(String(localized: "Profile Photo")) {
                    photoCard
                }

                cardSection(String(localized: "Basic Information")) {
                    basicInfoCard
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                // Decode off the main actor: UIImage(data:) on a full-resolution
                // photo can be expensive enough to visibly stall the UI.
                guard let image = await Task.detached(priority: .userInitiated, operation: {
                    UIImage(data: data)
                }).value else { return }
                await viewModel.uploadProfilePhoto(image)
            }
        }
    }

    // MARK: - Photo Card

    @ViewBuilder
    private var photoCard: some View {
        VStack(spacing: 16) {
            if let image = viewModel.profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.tertiary)
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo")
            }
            .accessibilityLabel(String(localized: "Choose profile photo"))
            .disabled(viewModel.isReadOnly)

            if viewModel.profileImage != nil {
                Button(role: .destructive) {
                    viewModel.showDeletePhotoConfirmation = true
                } label: {
                    Text("Delete Photo")
                }
                .disabled(viewModel.isReadOnly)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Basic Info Card

    @ViewBuilder
    private var basicInfoCard: some View {
        VStack(spacing: 0) {
            gradYearRow
            divider
            primarySportRow
            divider
            textRow(String(localized: "High School"), keyPath: \.highSchool)
            divider
            textRow(String(localized: "City"), keyPath: \.schoolCity)
            divider
            textRow(String(localized: "State"), keyPath: \.schoolState, autocapitalization: .characters)
        }
    }

    @ViewBuilder
    private var gradYearRow: some View {
        HStack {
            Text("Graduation Year")
            Spacer()
            Picker(
                "Graduation Year",
                selection: Binding(
                    get: { viewModel.details.graduationYear ?? currentYear },
                    set: { viewModel.updateGraduationYear($0) }
                )
            ) {
                ForEach(GradeLevelHelper.allowedGraduationYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100, height: 80)
            .clipped()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var primarySportRow: some View {
        HStack {
            Text("Primary Sport")
            Spacer()
            Picker(
                "Primary Sport",
                selection: Binding(
                    get: { viewModel.details.primarySport ?? "" },
                    set: {
                        viewModel.details.primarySport = $0.isEmpty ? nil : $0
                        viewModel.markChanged()
                    }
                )
            ) {
                Text("Select").tag("")
                ForEach(sports, id: \.self) { sport in
                    Text(sport).tag(sport)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func textRow(
        _ label: String,
        keyPath: WritableKeyPath<PlayerDetails, String?>,
        autocapitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, text: Binding(
                get: { viewModel.details[keyPath: keyPath] ?? "" },
                set: {
                    viewModel.details[keyPath: keyPath] = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            ))
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .textInputAutocapitalization(autocapitalization)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func cardSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            content()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var divider: some View { Divider().padding(.leading) }
}

#Preview {
    NavigationStack {
        BasicsTab(viewModel: PlayerDetailsViewModel(
            preferenceService: PreferencePreviewMock(defaultValue: PlayerDetails.default),
            userRole: .player
        ))
    }
}
