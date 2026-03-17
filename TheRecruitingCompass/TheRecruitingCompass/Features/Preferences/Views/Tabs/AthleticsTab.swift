import SwiftUI

struct AthleticsTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                cardSection("Physical Stats") {
                    physicalStatsCard
                }

                cardSection("Positions") {
                    PositionChipsView(
                        sport: viewModel.details.primarySport,
                        selectedPositions: Binding(
                            get: { viewModel.details.positions ?? [] },
                            set: {
                                viewModel.details.positions = $0.isEmpty ? nil : $0
                                viewModel.markChanged()
                            }
                        ),
                        isDisabled: viewModel.isReadOnly
                    )
                    .padding()
                }

                if viewModel.isBaseballOrSoftball {
                    cardSection("Baseball / Softball") {
                        baseballCard
                    }
                    .animation(.easeInOut, value: viewModel.isBaseballOrSoftball)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                cardSection("External IDs") {
                    externalIdsCard
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Physical Stats Card

    @ViewBuilder
    private var physicalStatsCard: some View {
        VStack(spacing: 0) {
            heightRow
            divider
            weightRow
        }
    }

    @ViewBuilder
    private var heightRow: some View {
        HStack {
            Text("Height").font(.body)
            Spacer()
            Picker(
                "Feet",
                selection: Binding(
                    get: { viewModel.heightFeet },
                    set: { viewModel.updateHeight(feet: $0, inches: viewModel.heightInchesRemainder) }
                )
            ) {
                ForEach(4...7, id: \.self) { ft in
                    Text("\(ft) ft").tag(ft)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80, height: 80)
            .clipped()

            Picker(
                "Inches",
                selection: Binding(
                    get: { viewModel.heightInchesRemainder },
                    set: { viewModel.updateHeight(feet: viewModel.heightFeet, inches: $0) }
                )
            ) {
                ForEach(0...11, id: \.self) { i in
                    Text("\(i) in").tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80, height: 80)
            .clipped()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var weightRow: some View {
        HStack {
            Text("Weight (lbs)").font(.body)
            Spacer()
            TextField("Weight", value: Binding(
                get: { viewModel.details.weightLbs },
                set: {
                    viewModel.details.weightLbs = $0
                    viewModel.markChanged()
                }
            ), format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Baseball Card

    @ViewBuilder
    private var baseballCard: some View {
        VStack(spacing: 0) {
            segmentedRow(
                "Bats",
                selection: Binding<String>(
                    get: { viewModel.details.bats ?? "" },
                    set: {
                        viewModel.details.bats = $0.isEmpty ? nil : $0
                        viewModel.markChanged()
                    }
                ),
                tags: [("", "–"), ("R", "Right (R)"), ("L", "Left (L)"), ("S", "Switch (S)")]
            )
            divider
            segmentedRow(
                "Throws",
                selection: Binding<String>(
                    get: { viewModel.details.throws_ ?? "" },
                    set: {
                        viewModel.details.throws_ = $0.isEmpty ? nil : $0
                        viewModel.markChanged()
                    }
                ),
                tags: [("", "–"), ("R", "Right (R)"), ("L", "Left (L)")]
            )
        }
    }

    // MARK: - External IDs Card

    @ViewBuilder
    private var externalIdsCard: some View {
        VStack(spacing: 0) {
            if viewModel.isBaseballOrSoftball {
                textRow("Perfect Game ID", keyPath: \.perfectGameId)
                divider
                textRow("Prep Baseball ID", keyPath: \.prepBaseballId)
                divider
            }
            textRow("NCAA ID", keyPath: \.ncaaId)
        }
    }

    // MARK: - Row Helpers

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

    private func segmentedRow<Tag: Hashable>(_ label: String, selection: Binding<Tag>, tags: [(Tag, String)]) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(Array(tags.enumerated()), id: \.offset) { _, pair in
                    Text(pair.1).tag(pair.0)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Card Section Helper

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
        AthleticsTab(viewModel: PlayerDetailsViewModel(
            preferenceService: PreferencePreviewMock(defaultValue: PlayerDetails.default),
            userRole: .player
        ))
    }
}
