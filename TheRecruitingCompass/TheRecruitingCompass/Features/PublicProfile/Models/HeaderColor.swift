import SwiftUI

/// Mirrors web `utils/profile/headerColor.ts` — the hero background maps to
/// Tailwind *-900 (dark) swatches; approximated as sRGB hex, family-recognizable,
/// exact match not required.
enum HeaderColor: String, CaseIterable, Sendable {
    case slate, blue, indigo, violet, rose, amber, emerald, teal

    /// Setup-panel swatch choices (6, parity with web `HEADER_COLORS` picker —
    /// amber/emerald remain valid stored values but aren't offered as swatches).
    static let setupSwatches: [HeaderColor] = [.slate, .blue, .teal, .rose, .violet, .indigo]

    var label: String {
        switch self {
        case .slate: return String(localized: "Navy")
        case .blue: return String(localized: "Blue")
        case .indigo: return String(localized: "Indigo")
        case .violet: return String(localized: "Violet")
        case .rose: return String(localized: "Rose")
        case .amber: return String(localized: "Amber")
        case .emerald: return String(localized: "Emerald")
        case .teal: return String(localized: "Teal")
        }
    }

    var color: Color {
        switch self {
        case .slate: return Color(hex: 0x0F172A)
        case .blue: return Color(hex: 0x1E3A8A)
        case .indigo: return Color(hex: 0x312E81)
        case .violet: return Color(hex: 0x4C1D95)
        case .rose: return Color(hex: 0x881337)
        case .amber: return Color(hex: 0x78350F)
        case .emerald: return Color(hex: 0x064E3B)
        case .teal: return Color(hex: 0x134E4A)
        }
    }

    static func from(_ key: String) -> HeaderColor {
        HeaderColor(rawValue: key) ?? .slate
    }
}

fileprivate extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
