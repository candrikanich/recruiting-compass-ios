import SwiftUI

struct PersonalFitCard: View {
    let analysis: PersonalFitAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal Fit").font(.headline)
                Spacer()
                Text("Based on your preferences")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if analysis.availableSignals == 0 {
                Text("Add your home state, campus size preference, and cost sensitivity in your profile to see personal fit.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(analysis.orderedSignals, id: \.label) { signal in
                    PersonalFitSignalRow(signal: signal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
    }
}

private struct PersonalFitSignalRow: View {
    let signal: PersonalFitSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                BadgeView(text: signal.label, color: signal.strength.badgeColor)
                if let value = signal.value {
                    Text(value).font(.subheadline).fontWeight(.medium)
                }
                Spacer()
            }
            Text(signal.explanation)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension FitSignalStrength {
    var badgeColor: BadgeColor {
        switch self {
        case .strong: return .emerald
        case .good: return .orange
        case .stretch: return .red
        case .unknown: return .slate
        }
    }
}

#Preview {
    PersonalFitCard(analysis: PersonalFitAnalysis(
        location: PersonalFitSignal(label: "Location", value: "In-state", strength: .strong,
            explanation: "In-state tuition typically applies."),
        campusSize: PersonalFitSignal(label: "Campus Size", value: "Large (30,000 students)", strength: .stretch,
            explanation: "This is a large campus; you prefer small."),
        cost: PersonalFitSignal(label: "Cost", value: "$18,000/yr", strength: .strong,
            explanation: "Cost is well within range.")))
    .padding()
}
