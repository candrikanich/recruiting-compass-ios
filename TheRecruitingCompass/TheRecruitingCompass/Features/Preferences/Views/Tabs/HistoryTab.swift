import SwiftUI

struct HistoryTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cardSection(String(localized: "High School Career")) {
                    VStack(spacing: 0) {
                        gradeSection(String(localized: "9th Grade"), team: \.ninthGradeTeam, coach: \.ninthGradeCoach)
                        Divider()
                        gradeSection(String(localized: "10th Grade"), team: \.tenthGradeTeam, coach: \.tenthGradeCoach)
                        Divider()
                        gradeSection(
                            String(localized: "11th Grade"), team: \.eleventhGradeTeam, coach: \.eleventhGradeCoach
                        )
                        Divider()
                        gradeSection(
                            String(localized: "12th Grade"), team: \.twelfthGradeTeam, coach: \.twelfthGradeCoach
                        )
                    }
                }

                cardSection(String(localized: "Travel Teams")) {
                    travelTeamsCard
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Travel Teams

    @ViewBuilder
    private var travelTeamsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add each org you've played for — most recent shows on your profile.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 12)

            let teams = viewModel.details.travelTeams ?? []
            if teams.isEmpty {
                Divider().padding(.leading)
                Text("No travel teams added yet.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            } else {
                ForEach(teams.indices, id: \.self) { index in
                    Divider().padding(.leading)
                    travelTeamRow(index: index)
                }
            }

            Divider().padding(.leading)
            Button {
                viewModel.addTravelTeam()
            } label: {
                Label("Add Travel Team", systemImage: "plus.circle.fill")
                    .font(.body)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .disabled(viewModel.isReadOnly)
        }
    }

    @ViewBuilder
    private func travelTeamRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Team \(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    viewModel.removeTravelTeam(at: index)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Remove travel team \(index + 1)"))
                .disabled(viewModel.isReadOnly)
            }
            .padding(.horizontal)
            .padding(.top, 10)

            travelYearRow(index: index)
            Divider().padding(.leading)
            travelTextRow(String(localized: "Organization"), index: index, field: \.name)
            Divider().padding(.leading)
            travelTextRow(String(localized: "Head Coach"), index: index, field: \.coach)
        }
    }

    private func team(at index: Int) -> TravelTeam? {
        guard let teams = viewModel.details.travelTeams, teams.indices.contains(index) else { return nil }
        return teams[index]
    }

    private func travelYearRow(index: Int) -> some View {
        HStack {
            Text("Season Year").font(.body)
            Spacer()
            TextField(
                "Season Year",
                value: Binding(
                    get: { team(at: index)?.year },
                    set: {
                        guard viewModel.details.travelTeams?.indices.contains(index) == true else { return }
                        viewModel.details.travelTeams?[index].year = $0
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

    private func travelTextRow(
        _ label: String,
        index: Int,
        field: WritableKeyPath<TravelTeam, String?>
    ) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField(label, text: Binding(
                get: { team(at: index)?[keyPath: field] ?? "" },
                set: {
                    guard viewModel.details.travelTeams?.indices.contains(index) == true else { return }
                    viewModel.details.travelTeams?[index][keyPath: field] = $0.isEmpty ? nil : $0
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
            textRow(String(localized: "Team"), keyPath: team)
            Divider().padding(.leading)
            textRow(String(localized: "Coach"), keyPath: coach)
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
