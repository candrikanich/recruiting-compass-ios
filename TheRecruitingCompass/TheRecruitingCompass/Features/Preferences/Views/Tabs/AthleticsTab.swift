import SwiftUI

struct AthleticsTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                cardSection(String(localized: "Physical Profile")) {
                    physicalStatsCard
                }

                if viewModel.isBaseballOrSoftball {
                    cardSection(sportSectionTitle) {
                        battingThrowingCard
                    }
                }

                cardSection(String(localized: "Positions You Play")) {
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

                if let positions = viewModel.details.positions, !positions.isEmpty {
                    cardSection(String(localized: "Position Priority")) {
                        positionPriorityCard(positions)
                    }
                }

                cardSection(String(localized: "Recruiting Database IDs")) {
                    externalIdsCard
                }

                cardSection(String(localized: "Video Links")) {
                    videoLinksRow
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

    // MARK: - Batting & Throwing Card (baseball/softball only)

    /// Section title keyed to the athlete's primary sport (e.g. "Baseball"),
    /// falling back to a sport-agnostic label if none is set.
    private var sportSectionTitle: String {
        guard let sport = viewModel.details.primarySport, !sport.isEmpty else {
            return String(localized: "Batting & Throwing")
        }
        return sport.capitalized
    }

    @ViewBuilder
    private var battingThrowingCard: some View {
        VStack(spacing: 0) {
            choiceRow(
                String(localized: "Bats"),
                options: [
                    ("R", String(localized: "Right")),
                    ("L", String(localized: "Left")),
                    ("S", String(localized: "Switch"))
                ],
                selection: Binding(
                    get: { viewModel.details.bats },
                    set: {
                        viewModel.details.bats = $0
                        viewModel.markChanged()
                    }
                )
            )
            divider
            choiceRow(
                String(localized: "Throws"),
                options: [
                    ("R", String(localized: "Right")),
                    ("L", String(localized: "Left"))
                ],
                selection: Binding(
                    get: { viewModel.details.throws_ },
                    set: {
                        viewModel.details.throws_ = $0
                        viewModel.markChanged()
                    }
                )
            )
        }
        .animation(.easeInOut, value: viewModel.isBaseballOrSoftball)
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

    // MARK: - Video Links

    /// Row pushing the shared Video Links editor. The editor owns its own toolbar
    /// "Add" button, so it must be pushed rather than embedded inline.
    @ViewBuilder
    private var videoLinksRow: some View {
        NavigationLink {
            VideoLinksEditorView(
                athleteUserId: viewModel.athleteUserId,
                familyUnitId: FamilyManager.shared.currentMember?.familyUnitId,
                isReadOnly: viewModel.isReadOnly
            )
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Video Links")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("Hudl, YouTube, or Vimeo highlight reels")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - External IDs Card

    @ViewBuilder
    private var externalIdsCard: some View {
        VStack(spacing: 0) {
            if viewModel.isBaseballOrSoftball {
                textRow(String(localized: "Perfect Game ID"), keyPath: \.perfectGameId)
                helperLink(String(localized: "Get your Perfect Game profile"), "https://www.perfectgame.org/")
                divider
                textRow(String(localized: "Prep Baseball ID"), keyPath: \.prepBaseballId)
                helperLink(String(localized: "Get your Prep Baseball Report profile"),
                           "https://www.prepbaseballreport.com/")
                divider
            }
            textRow(String(localized: "NCAA ID"), keyPath: \.ncaaId)
            helperLink(String(localized: "Register at NCAA Eligibility Center"), "https://web3.ncaa.org/ecwr3/")
        }
    }

    @ViewBuilder
    private func helperLink(_ title: String, _ urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 4) {
                    Text(title)
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Position Priority

    /// Selected positions in priority order — index 0 = primary, 1 = secondary.
    /// This ordering is what coach outreach, the recruiting packet, and the
    /// public profile display, so athletes control it explicitly here.
    @ViewBuilder
    private func positionPriorityCard(_ positions: [String]) -> some View {
        VStack(spacing: 0) {
            Text("Order matters — your first pick is what coaches see (they recruit for specific positions).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)
            ForEach(Array(positions.enumerated()), id: \.element) { index, pos in
                positionPriorityRow(index: index, pos: pos, count: positions.count)
                if index < positions.count - 1 { divider }
            }
        }
    }

    private func positionPriorityRow(index: Int, pos: String, count: Int) -> some View {
        HStack(spacing: 12) {
            priorityBadge(index)
            Text(pos).font(.body)
            Text(CanonicalPositions.abbreviation(sport: viewModel.details.primarySport, pos))
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                viewModel.movePosition(index, .up)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(index == 0 || viewModel.isReadOnly)
            .accessibilityLabel(String(localized: "Move \(pos) up"))

            Button {
                viewModel.movePosition(index, .down)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(index == count - 1 || viewModel.isReadOnly)
            .accessibilityLabel(String(localized: "Move \(pos) down"))
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func priorityBadge(_ index: Int) -> some View {
        switch index {
        case 0:
            badgeLabel(String(localized: "PRIMARY"), background: Color.accentColor, foreground: .white)
        case 1:
            badgeLabel(String(localized: "SECONDARY"), background: Color(.tertiarySystemFill), foreground: .primary)
        default:
            Text("\(index + 1)")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .frame(width: 28)
        }
    }

    private func badgeLabel(_ text: String, background: Color, foreground: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
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

    /// Web-parity segmented selector: selected option gets a filled accent highlight
    /// (the system `.segmented` style rendered selection too subtly to read).
    private func choiceRow(
        _ label: String,
        options: [(value: String, label: String)],
        selection: Binding<String?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(options, id: \.value) { opt in
                    let isSelected = selection.wrappedValue == opt.value
                    Button {
                        selection.wrappedValue = opt.value
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
