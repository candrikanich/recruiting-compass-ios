import SwiftUI

struct HistoryTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cardSection("High School Career") {
                    VStack(spacing: 0) {
                        gradeSection("9th Grade", team: \.ninthGradeTeam, coach: \.ninthGradeCoach)
                        Divider()
                        gradeSection("10th Grade", team: \.tenthGradeTeam, coach: \.tenthGradeCoach)
                        Divider()
                        gradeSection("11th Grade", team: \.eleventhGradeTeam, coach: \.eleventhGradeCoach)
                        Divider()
                        gradeSection("12th Grade", team: \.twelfthGradeTeam, coach: \.twelfthGradeCoach)
                    }
                }

                cardSection("Travel Team") {
                    VStack(spacing: 0) {
                        travelYearRow
                        divider
                        textRow("Team Name", keyPath: \.travelTeamName)
                        divider
                        textRow("Coach Name", keyPath: \.travelTeamCoach)
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Travel Year Row

    @ViewBuilder
    private var travelYearRow: some View {
        HStack {
            Text("Year").font(.body)
            Spacer()
            TextField(
                "Year",
                value: Binding(
                    get: { viewModel.details.travelTeamYear },
                    set: {
                        viewModel.details.travelTeamYear = $0
                        viewModel.markChanged()
                    }
                ),
                format: .number
            )
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .keyboardType(.numberPad)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func textRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, String?>) -> some View {
        HStack {
            Text(label).font(.body)
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
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func gradeSection(
        _ label: String,
        team: WritableKeyPath<PlayerDetails, String?>,
        coach: WritableKeyPath<PlayerDetails, String?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 10)
            textRow("Team", keyPath: team)
            Divider().padding(.leading)
            textRow("Coach", keyPath: coach)
        }
    }

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
        HistoryTab(viewModel: PlayerDetailsViewModel(
            preferenceService: PreferencePreviewMock(defaultValue: PlayerDetails.default),
            userRole: .player
        ))
    }
}
