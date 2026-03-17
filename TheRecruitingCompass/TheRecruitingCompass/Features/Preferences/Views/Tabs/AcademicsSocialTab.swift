import SwiftUI

struct AcademicsSocialTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cardSection("Academics") {
                    VStack(spacing: 0) {
                        numericRow("GPA", keyPath: \.gpa)
                        divider
                        intRow("SAT Score", keyPath: \.satScore)
                        divider
                        intRow("ACT Score", keyPath: \.actScore)
                    }
                }

                cardSection("Social Media") {
                    VStack(spacing: 0) {
                        textRow("Twitter", placeholder: "@username", keyPath: \.twitterHandle)
                        divider
                        textRow("Instagram", placeholder: "@username", keyPath: \.instagramHandle)
                        divider
                        textRow("TikTok", placeholder: "@username", keyPath: \.tiktokHandle)
                        divider
                        textRow("Facebook URL", placeholder: "https://...", keyPath: \.facebookUrl, keyboardType: .URL)
                    }
                }

                cardSection("Privacy") {
                    VStack(spacing: 0) {
                        toggleRow("Share phone with coaches", keyPath: \.allowSharePhone)
                        divider
                        toggleRow("Share email with coaches", keyPath: \.allowShareEmail)
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
