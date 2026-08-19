import SwiftUI

struct AcademicsSocialTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cardSection(String(localized: "High School")) {
                    VStack(spacing: 0) {
                        textRow(String(localized: "High School"), keyPath: \.highSchool)
                        divider
                        textRow(String(localized: "City"), keyPath: \.schoolCity)
                        divider
                        textRow(String(localized: "State"), keyPath: \.schoolState, autocapitalization: .characters)
                    }
                }

                cardSection(String(localized: "Academics")) {
                    VStack(spacing: 0) {
                        numericRow(String(localized: "GPA"), keyPath: \.gpa)
                        divider
                        intRow(String(localized: "SAT Score"), keyPath: \.satScore)
                        divider
                        intRow(String(localized: "ACT Score"), keyPath: \.actScore)
                        divider
                        textRow(String(localized: "Intended Major"), keyPath: \.intendedMajor)
                    }
                }

                cardSection(String(localized: "Core Courses")) {
                    CoreCoursesEditor(
                        courses: Binding(
                            get: { viewModel.details.coreCourses ?? [] },
                            set: {
                                viewModel.details.coreCourses = $0.isEmpty ? nil : $0
                                viewModel.markChanged()
                            }
                        ),
                        isDisabled: viewModel.isReadOnly
                    )
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
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences
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
            .textInputAutocapitalization(autocapitalization)
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
            ), format: .number.grouping(.never))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
            .frame(width: 80)
        }
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
