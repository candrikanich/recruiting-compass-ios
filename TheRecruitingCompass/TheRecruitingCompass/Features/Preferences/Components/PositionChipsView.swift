import SwiftUI

struct PositionChipsView: View {
    let sport: String?
    @Binding var selectedPositions: [String]
    let isDisabled: Bool

    private var availablePositions: [String] {
        switch sport?.lowercased() {
        case "baseball", "softball":
            return ["Pitcher", "Catcher", "First Base", "Second Base", "Third Base",
                    "Shortstop", "Left Field", "Center Field", "Right Field", "Designated Hitter"]
        case "basketball":
            return ["Point Guard", "Shooting Guard", "Small Forward", "Power Forward", "Center"]
        case "football":
            return ["Quarterback", "Running Back", "Wide Receiver", "Tight End", "Offensive Line",
                    "Defensive Line", "Linebacker", "Cornerback", "Safety", "Kicker", "Punter"]
        case "soccer":
            return ["Goalkeeper", "Defender", "Midfielder", "Forward", "Winger", "Sweeper"]
        default:
            return []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Positions")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if availablePositions.isEmpty {
                Text("Select a sport above to choose positions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ChipFlowLayout(spacing: 8) {
                    ForEach(availablePositions, id: \.self) { position in
                        PositionChip(
                            title: position,
                            isSelected: selectedPositions.contains(position),
                            isDisabled: isDisabled
                        ) {
                            toggle(position)
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ position: String) {
        guard !isDisabled else { return }
        if let idx = selectedPositions.firstIndex(of: position) {
            selectedPositions.remove(at: idx)
        } else {
            selectedPositions.append(position)
        }
    }
}

private struct PositionChip: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .disabled(isDisabled)
        .accessibilityLabel(String(localized: "\(title), \(isSelected ? "selected" : "not selected")"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let totalHeight = rows.map { row in
            row.map { $0.size.height }.max() ?? 0
        }.reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, totalHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.size.height }.max() ?? 0
            for item in row {
                item.view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private struct RowItem {
        let view: LayoutSubview
        let size: CGSize
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[RowItem]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[RowItem]] = [[]]
        var currentWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.endIndex - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.endIndex - 1].append(RowItem(view: view, size: size))
            currentWidth += size.width + spacing
        }
        return rows.filter { !$0.isEmpty }
    }
}

#Preview {
    @Previewable @State var positions: [String] = ["Pitcher"]
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            PositionChipsView(sport: "Baseball", selectedPositions: $positions, isDisabled: false)
            PositionChipsView(sport: "Basketball", selectedPositions: $positions, isDisabled: false)
            PositionChipsView(sport: nil, selectedPositions: $positions, isDisabled: false)
        }
        .padding()
    }
}
