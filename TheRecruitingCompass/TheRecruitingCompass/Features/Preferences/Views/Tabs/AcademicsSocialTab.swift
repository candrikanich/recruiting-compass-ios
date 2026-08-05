import SwiftUI

struct AcademicsSocialTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cardSection(String(localized: "Academics")) {
                    VStack(spacing: 0) {
                        numericRow(String(localized: "GPA"), keyPath: \.gpa)
                        divider
                        intRow(String(localized: "SAT Score"), keyPath: \.satScore)
                        divider
                        intRow(String(localized: "ACT Score"), keyPath: \.actScore)
                    }
                }

                cardSection(String(localized: "Social Media")) {
                    VStack(spacing: 0) {
                        textRow(
                            String(localized: "Twitter"),
                            placeholder: String(localized: "@username"),
                            keyPath: \.twitterHandle
                        )
                        divider
                        textRow(
                            String(localized: "Instagram"),
                            placeholder: String(localized: "@username"),
                            keyPath: \.instagramHandle
                        )
                        divider
                        textRow(
                            String(localized: "TikTok"),
                            placeholder: String(localized: "@username"),
                            keyPath: \.tiktokHandle
                        )
                        divider
                        textRow(
                            String(localized: "Facebook URL"),
                            placeholder: String(localized: "https://..."),
                            keyPath: \.facebookUrl,
                            keyboardType: .URL
                        )
                    }
                }

                cardSection(String(localized: "Privacy")) {
                    VStack(spacing: 0) {
                        toggleRow(String(localized: "Share phone with coaches"), keyPath: \.allowSharePhone)
                        divider
                        toggleRow(String(localized: "Share email with coaches"), keyPath: \.allowShareEmail)
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Row Helpers

    private func textRow(
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

    private func numericRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, Double?>) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField("–", value: Binding(
                get: { viewModel.details[keyPath: keyPath] },
                set: {
                    viewModel.details[keyPath: keyPath] = $0
                    viewModel.markChanged()
                }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
            .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func intRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, Int?>) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField("–", value: Binding(
                get: { viewModel.details[keyPath: keyPath] },
                set: {
                    viewModel.details[keyPath: keyPath] = $0
                    viewModel.markChanged()
                }
            ), format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
            .frame(width: 80)
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

    // MARK: - Card Helpers

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
        AcademicsSocialTab(viewModel: PlayerDetailsViewModel(
            preferenceService: PreferencePreviewMock(defaultValue: PlayerDetails.default),
            userRole: .player
        ))
    }
}
