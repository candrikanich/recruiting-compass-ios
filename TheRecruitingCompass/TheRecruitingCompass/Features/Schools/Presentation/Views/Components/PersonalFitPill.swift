import SwiftUI

/// Compact tile pill summarizing overall personal fit. Renders nothing when unknown.
struct PersonalFitPill: View {
    let overall: OverallPersonalFit?

    var body: some View {
        if let overall {
            BadgeView(text: overall.label, color: overall.badgeColor)
                .accessibilityLabel(String(localized: "Personal fit: \(overall.label)"))
        }
    }
}

#Preview {
    VStack {
        PersonalFitPill(overall: OverallPersonalFit(strength: .strong))
        PersonalFitPill(overall: OverallPersonalFit(strength: .good))
        PersonalFitPill(overall: OverallPersonalFit(strength: .stretch))
        PersonalFitPill(overall: nil)
    }
}
