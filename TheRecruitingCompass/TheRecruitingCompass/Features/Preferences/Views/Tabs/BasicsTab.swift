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

                cardSection(String(localized: "Contact")) {
                    contactCard
                }

                cardSection(String(localized: "Social")) {
                    socialCard
                }

                cardSection(String(localized: "College Preferences")) {
                    collegePrefsCard
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
        HStack(alignment: .center, spacing: 20) {
            photoImage

            VStack(alignment: .leading, spacing: 16) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo")
                }
                .accessibilityLabel(String(localized: "Choose profile photo"))
                .disabled(viewModel.isReadOnly)

                if viewModel.profileImage != nil || viewModel.photoUrl != nil {
                    Button(role: .destructive) {
                        viewModel.showDeletePhotoConfirmation = true
                    } label: {
                        Label("Delete Photo", systemImage: "trash")
                    }
                    .disabled(viewModel.isReadOnly)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var photoImage: some View {
        if let image = viewModel.profileImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
        } else if let urlString = viewModel.photoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().scaledToFit().foregroundStyle(.tertiary)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Basic Info Card

    @ViewBuilder
    private var basicInfoCard: some View {
        VStack(spacing: 0) {
            gradYearRow
            divider
            primarySportRow
            divider
            genderRow
        }
    }

    // MARK: - Contact Card

    @ViewBuilder
    private var contactCard: some View {
        VStack(spacing: 0) {
            phoneRow(String(localized: "Phone"), placeholder: String(localized: "(555) 123-4567"),
                     keyPath: \.phone)
            divider
            handleRow(String(localized: "Email"), placeholder: String(localized: "Email"),
                      keyPath: \.email, keyboardType: .emailAddress)
            divider
            toggleRow(String(localized: "Share phone with coaches"), keyPath: \.allowSharePhone)
            divider
            toggleRow(String(localized: "Share email with coaches"), keyPath: \.allowShareEmail)
        }
    }

    // MARK: - Social Card

    @ViewBuilder
    private var socialCard: some View {
        VStack(spacing: 0) {
            handleRow(String(localized: "Twitter"), placeholder: String(localized: "@username"), keyPath: \.twitterHandle)
            divider
            handleRow(String(localized: "Instagram"), placeholder: String(localized: "@username"), keyPath: \.instagramHandle)
            divider
            handleRow(String(localized: "TikTok"), placeholder: String(localized: "@username"), keyPath: \.tiktokHandle)
            divider
            handleRow(String(localized: "Facebook URL"), placeholder: String(localized: "https://..."), keyPath: \.facebookUrl, keyboardType: .URL)
        }
    }

    private func handleRow(
        _ label: String,
        placeholder: String = "",
        keyPath: WritableKeyPath<PlayerDetails, String?>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField(placeholder.isEmpty ? label : placeholder, text: Binding(
                get: { viewModel.details[keyPath: keyPath] ?? "" },
                set: {
                    viewModel.details[keyPath: keyPath] = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            ))
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func phoneRow(
        _ label: String,
        placeholder: String = "",
        keyPath: WritableKeyPath<PlayerDetails, String?>
    ) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField(placeholder.isEmpty ? label : placeholder, text: Binding(
                get: { PhoneFormatter.formatNational(viewModel.details[keyPath: keyPath] ?? "") },
                set: {
                    viewModel.details[keyPath: keyPath] = PhoneFormatter.toStored($0)
                    viewModel.markChanged()
                }
            ))
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .keyboardType(.phonePad)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func toggleRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, Bool?>) -> some View {
        Toggle(label, isOn: Binding(
            get: { viewModel.details[keyPath: keyPath] ?? false },
            set: {
                viewModel.details[keyPath: keyPath] = $0
                viewModel.markChanged()
            }
        ))
        .disabled(viewModel.isReadOnly)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - College Preferences Card

    private let campusSizeOptions: [(value: String, label: String)] = [
        ("small", "Small (<5K)"),
        ("medium", "Mid (5K–25K)"),
        ("large", "Large (25K+)")
    ]

    private let costSensitivityOptions: [(value: String, label: String)] = [
        ("high", "High"),
        ("medium", "Medium"),
        ("low", "Low")
    ]

    @ViewBuilder
    private var collegePrefsCard: some View {
        VStack(spacing: 0) {
            segmentedRow(
                String(localized: "Campus Size Preference"),
                options: campusSizeOptions,
                keyPath: \.campusSizePreference
            )
            divider
            segmentedRow(
                String(localized: "Cost Sensitivity"),
                options: costSensitivityOptions,
                keyPath: \.costSensitivity
            )
        }
    }

    /// Web-parity segmented selector matching `AthleticsTab.choiceRow`: the
    /// selected option gets a filled accent highlight. Tapping the selected
    /// option again clears it (these preferences are optional).
    private func segmentedRow(
        _ label: String,
        options: [(value: String, label: String)],
        keyPath: WritableKeyPath<PlayerDetails, String?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(options, id: \.value) { opt in
                    let isSelected = viewModel.details[keyPath: keyPath] == opt.value
                    Button {
                        viewModel.details[keyPath: keyPath] = isSelected ? nil : opt.value
                        viewModel.markChanged()
                    } label: {
                        Text(opt.label)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isReadOnly)
                    .accessibilityLabel("\(label): \(opt.label)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            Text("Used for personal fit analysis")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
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

    @ViewBuilder
    private var genderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Gender (optional)")).font(.subheadline.weight(.medium))
            Picker(String(localized: "Gender"), selection: Binding(
                get: { viewModel.details.gender ?? "" },
                set: {
                    viewModel.details.gender = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            )) {
                Text(String(localized: "Prefer not to answer")).tag("")
                ForEach(Gender.allCases, id: \.rawValue) { g in
                    Text(g.displayName).tag(g.rawValue)
                }
            }
            .pickerStyle(.menu)
            .disabled(viewModel.isReadOnly)
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
