import SwiftUI

extension Color {
    static let primaryGreen = Color(red: 0.024, green: 0.588, blue: 0.412)
    static let darkEmerald = Color(red: 0.016, green: 0.522, blue: 0.373)
    static let emeraldGradientStart = Color(red: 0.3, green: 0.6, blue: 0.4)
    static let emeraldGradientEnd = Color(red: 0.05, green: 0.5, blue: 0.35)

    static let darkSlate = Color(red: 0.216, green: 0.263, blue: 0.322)
    static let secondaryText = Color(red: 0.35, green: 0.40, blue: 0.48)
    static let tertiaryText = Color(red: 0.282, green: 0.337, blue: 0.431)
    static let nearBlack = Color(red: 0.05, green: 0.05, blue: 0.1)

    static let accentBlue = Color(red: 0.149, green: 0.388, blue: 0.931)
    static let blueGradientStart = Color(red: 0, green: 0.4, blue: 1)
    static let blueGradientEnd = Color(red: 0, green: 0.32, blue: 0.8)

    static let errorRed = Color(red: 0.859, green: 0.149, blue: 0.149)
    static let errorBackground = Color(red: 0.996, green: 0.886, blue: 0.886)
    static let errorBorder = Color(red: 0.996, green: 0.792, blue: 0.792)

    static let warningOrange = Color(red: 0.576, green: 0.25, blue: 0.056)
    static let warningBackground = Color(red: 1, green: 0.984, blue: 0.92)
    static let warningBorder = Color(red: 0.996, green: 0.891, blue: 0.658)
    static let strengthOrange = Color(red: 1, green: 0.647, blue: 0)

    static let amberGold = Color(red: 0.77, green: 0.56, blue: 0)
    static let successGreen = Color(red: 0.2, green: 0.62, blue: 0.4)

    static let iconGray = Color(red: 0.627, green: 0.655, blue: 0.686)
    static let borderGray = Color(red: 0.827, green: 0.843, blue: 0.863)

    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)

        let r = Double((hexNumber & 0xff0000) >> 16) / 255
        let g = Double((hexNumber & 0x00ff00) >> 8) / 255
        let b = Double(hexNumber & 0x0000ff) / 255

        self.init(red: r, green: g, blue: b)
    }
}
