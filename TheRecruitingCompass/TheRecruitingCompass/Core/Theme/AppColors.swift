import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
  // MARK: - Brand Palette
  // Raw color values. Use Color.Brand.* or BadgeColor for semantic contexts.
  enum Brand {
    // Blue — primary actions, links, in-progress
    static let blue100 = Color(hex: "dbeafe")
    static let blue500 = Color(hex: "3b82f6")
    static let blue600 = Color(hex: "2563eb")
    static let blue700 = Color(hex: "1d4ed8")
    // Emerald — success, completed, inbound
    static let emerald100 = Color(hex: "d1fae5")
    static let emerald500 = Color(hex: "10b981")
    static let emerald600 = Color(hex: "059669")
    static let emerald700 = Color(hex: "047857")
    static let emerald800 = Color(hex: "065f46")
    // Orange — warning, pending, reach
    static let orange100 = Color(hex: "ffedd5")
    static let orange500 = Color(hex: "f97316")
    static let orange600 = Color(hex: "ea580c")
    static let orange700 = Color(hex: "c2410c")
    static let orange800 = Color(hex: "9a3412")
    // Purple — secondary, outbound, academic
    static let purple100 = Color(hex: "ede9fe")
    static let purple500 = Color(hex: "8b5cf6")
    static let purple600 = Color(hex: "7c3aed")
    static let purple700 = Color(hex: "6d28d9")
    // Red — error, danger, destructive, negative
    static let red100 = Color(hex: "fee2e2")
    static let red500 = Color(hex: "ef4444")
    static let red600 = Color(hex: "dc2626")
    static let red700 = Color(hex: "b91c1c")
    // Slate — neutral, disabled, default
    static let slate100 = Color(hex: "f1f5f9")
    static let slate500 = Color(hex: "64748b")
    static let slate600 = Color(hex: "475569")
    static let slate700 = Color(hex: "334155")
    // Pink — Instagram brand mark tint (web brand-pink-500)
    static let pink500 = Color(hex: "ec4899")
    // Sky — Twitter channel button (web brand-sky-500)
    static let sky500 = Color(hex: "0ea5e9")
    // Fuchsia — Instagram channel gradient start (web brand-fuchsia-500)
    static let fuchsia500 = Color(hex: "d946ef")
    // Indigo — accent (reserved for future button use)
    static let indigo100 = Color(hex: "e0e7ff")
    static let indigo500 = Color(hex: "6366f1")
    static let indigo600 = Color(hex: "4f46e5")
    static let indigo700 = Color(hex: "4338ca")
  }

  // MARK: - Semantic Aliases
  enum Semantic {
    static let actionPrimary = Color.Brand.blue600
    static let success = Color.Brand.emerald600
    static let warning = Color.Brand.orange600
    static let danger = Color.Brand.red600
    static let muted = Color.Brand.slate500
  }

  // MARK: - Legacy Aliases (bridge for existing callers)
  // Text-role aliases are adaptive: the light value is unchanged, the dark
  // value keeps WCAG AA contrast (>= 4.5:1) on Surface.card / Surface.background.
  static let primaryGreen = Color.Brand.emerald600
  static let darkEmerald = Color.Brand.emerald700
  static let emeraldGradientStart = Color.Brand.emerald500
  static let emeraldGradientEnd = Color.Brand.emerald600
  static let darkSlate = Color(light: Color.Brand.slate700, dark: Color(hex: "cbd5e1"))
  static let secondaryText = Color(light: Color.Brand.slate500, dark: Color(hex: "94a3b8"))
  static let tertiaryText = Color(light: Color.Brand.slate600, dark: Color(hex: "94a3b8"))
  static let nearBlack = Color(light: Color(hex: "0d0d1a"), dark: Color(hex: "f2f2f7"))
  static let accentBlue = Color.Brand.blue600
  static let blueGradientStart = Color.Brand.blue500
  static let blueGradientEnd = Color.Brand.blue700
  static let errorRed = Color.Brand.red600
  static let errorBackground = Color.Brand.red100
  static let errorBorder = Color(hex: "fecaca")
  static let warningOrange = Color.Brand.orange700
  static let warningBackground = Color.Brand.orange100
  static let warningBorder = Color(hex: "fed7aa")
  static let strengthOrange = Color.Brand.orange500
  static let amberGold = Color(light: Color(hex: "b45309"), dark: Color(hex: "fbbf24"))
  static let successGreen = Color.Brand.emerald600
  // Warning/success banner text (e.g. ParentOnboardingBanner) — paired with Surface.warningTint/successTint.
  static let warningBannerTitle = Color(light: Color(hex: "78350F"), dark: Color(hex: "FDE68A"))
  static let warningBannerBody = Color(light: Color(hex: "92400E"), dark: Color(hex: "FCD34D"))
  static let successBannerIcon = Color(light: Color(hex: "15803D"), dark: Color(hex: "4ADE80"))
  static let successBannerText = Color(light: Color(hex: "14532D"), dark: Color(hex: "BBF7D0"))
  static let iconGray = Color(light: Color.Brand.slate500, dark: Color(hex: "94a3b8"))
  static let borderGray = Color(light: Color.Brand.slate100, dark: Color.white.opacity(0.12))

  // MARK: - Tinted Surface Tokens
  // Every neutral carries a trace of the brand blue (#2563EB) so the brand
  // color feels native to the surface rather than sitting on top of it.
  enum Surface {
    static let background  = Color(light: Color(hex: "F4F6FA"), dark: Color(hex: "121212"))  // page/screen background
    static let card        = Color(light: Color(hex: "FAFBFD"), dark: Color(hex: "1E1E1E"))  // card / sheet background
    static let muted       = Color(light: Color(hex: "E8EDF5"), dark: Color(hex: "2A2A2A"))  // muted fills, disabled states
    static let border      = Color(light: Color(red: 30/255, green: 50/255, blue: 100/255).opacity(0.12), dark: Color.white.opacity(0.1))
    static let borderStrong = Color(light: Color(red: 30/255, green: 50/255, blue: 100/255).opacity(0.22), dark: Color.white.opacity(0.2))
    // Tinted status banners (e.g. ParentOnboardingBanner) — light tint on light mode, dark low-luminance tint on dark mode.
    static let warningTint   = Color(light: Color(hex: "FFFBEB"), dark: Color(hex: "3A2A0A"))
    static let warningAccent = Color(light: Color(hex: "F59E0B"), dark: Color(hex: "D97706"))
    static let warningCTA    = Color(light: Color(hex: "D97706"), dark: Color(hex: "F59E0B"))
    static let successTint   = Color(light: Color(hex: "F0FDF4"), dark: Color(hex: "0F2E1C"))
    static let successAccent = Color(light: Color(hex: "22C55E"), dark: Color(hex: "16A34A"))
  }

  // MARK: - Tinted Text Tokens
  enum Text {
    static let primary   = Color(light: Color(hex: "0F1523"), dark: Color(hex: "FFFFFF"))  // headings — cool near-black
    static let secondary = Color(light: Color(hex: "3A4560"), dark: Color(hex: "CCCCCC"))  // body copy
    static let muted     = Color(light: Color(hex: "7A8BA0"), dark: Color(hex: "888888"))  // captions, placeholder
  }

  // MARK: - Adaptive Light/Dark Initializer
  // Provides Color(light:dark:) using UIColor trait-based dynamic colors,
  // replacing the iOS 17 SwiftUI API that was removed in Xcode 26.3 SDK.
  #if canImport(UIKit)
  init(light: Color, dark: Color) {
    self = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
    })
  }
  #endif

  // MARK: - Hex Initializer
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
