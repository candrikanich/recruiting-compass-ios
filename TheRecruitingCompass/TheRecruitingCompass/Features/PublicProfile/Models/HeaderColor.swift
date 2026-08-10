import SwiftUI

/// Mirrors web ProfileSetup.vue HEADER_COLORS. Tailwind -700 swatches
/// approximated as sRGB hex; family-recognizable, exact match not required.
enum HeaderColor: String, CaseIterable, Sendable {
    case slate, blue, indigo, violet, rose, amber, emerald, teal

    var label: String {
        switch self {
        case .slate: return String(localized: "Slate")
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
        case .slate: return Color(hex: 0x334155)
        case .blue: return Color(hex: 0x1D4ED8)
        case .indigo: return Color(hex: 0x4338CA)
        case .violet: return Color(hex: 0x6D28D9)
        case .rose: return Color(hex: 0xBE123C)
        case .amber: return Color(hex: 0xD97706)
        case .emerald: return Color(hex: 0x047857)
        case .teal: return Color(hex: 0x0F766E)
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
