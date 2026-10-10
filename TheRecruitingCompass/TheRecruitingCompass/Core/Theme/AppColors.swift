import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
  // MARK: - Brand Palette
  // Raw color values. Use Color.Brand.* or BadgeColor for semantic contexts.
  // Role discipline (mirrors web docs/design/tokens.md): forest = actions/links/focus/selected;
  // gold = the single accent; clay = third categorical hue only; emerald/orange/red = success/warning/error only;
  // everything else is neutral. No decorative gradients. Never use raw system hues (.blue, .purple, ...).
  enum Brand {
    // Forest — primary: actions, links, focus, selected. Anchor 600 = logo green.
    static let forest50  = Color(hex: "f3f7f1")
    static let forest100 = Color(hex: "e3ede0")
    static let forest200 = Color(hex: "c6dbbf")
    static let forest300 = Color(hex: "9fc194")
    static let forest400 = Color(hex: "6f9e62")
    static let forest500 = Color(hex: "4a7d3f")
    static let forest600 = Color(hex: "2d5a27")
    static let forest700 = Color(hex: "254b20")
    static let forest800 = Color(hex: "1d3b19")
    static let forest900 = Color(hex: "152b12")
    // Gold — the single accent. Use 600+ for text on light surfaces (400 = 2.37:1, decoration only).
    static let gold100 = Color(hex: "f5eedc")
    static let gold200 = Color(hex: "ebdcb8")
    static let gold400 = Color(hex: "c4a46b")
    static let gold500 = Color(hex: "b08a45")
    static let gold600 = Color(hex: "8b6914")
    static let gold700 = Color(hex: "6f5410")
    static let gold900 = Color(hex: "3d2e09")
    // Clay — third categorical hue ONLY. Never decoration.
    static let clay100 = Color(hex: "f2e6dc")
    static let clay600 = Color(hex: "6b4423")
    static let clay700 = Color(hex: "573719")
    // Emerald — success, completed, inbound
    static let emerald100 = Color(hex: "d1fae5")
    static let emerald200 = Color(hex: "bbf7d0")
    static let emerald500 = Color(hex: "10b981")
    static let emerald600 = Color(hex: "059669")
    static let emerald700 = Color(hex: "047857")
    static let emerald800 = Color(hex: "065f46")
    static let emerald900 = Color(hex: "064e3b")
    // Orange — warning, pending, reach
    static let orange100 = Color(hex: "ffedd5")
    static let orange500 = Color(hex: "f97316")
    static let orange600 = Color(hex: "ea580c")
    static let orange700 = Color(hex: "c2410c")
    static let orange800 = Color(hex: "9a3412")
    // Red — error, danger, destructive, negative
    static let red100 = Color(hex: "fee2e2")
    static let red200 = Color(hex: "fecaca")
    static let red500 = Color(hex: "ef4444")
    static let red600 = Color(hex: "dc2626")
    static let red700 = Color(hex: "b91c1c")
    static let red900 = Color(hex: "7f1d1d")
    // Warm neutral ramp (stone) — neutral, disabled, default. Mirrors web's slate/gray override.
    static let slate50  = Color(hex: "fafaf8")
    static let slate100 = Color(hex: "f5f5f0")
    static let slate200 = Color(hex: "e7e5e0")
    static let slate300 = Color(hex: "d6d3cd")
    static let slate400 = Color(hex: "a8a29e")
    static let slate500 = Color(hex: "6b645f")
    static let slate600 = Color(hex: "57534e")
    static let slate700 = Color(hex: "44403c")
    static let slate800 = Color(hex: "292524")
    static let slate900 = Color(hex: "1c1917")
  }

  // MARK: - Categorical Palette
  // Forest -> gold -> clay -> slate, in that order, before adding anything else. Adaptive so the hues
  // stay legible on dark cards (the 600 steps fail AA there).
  enum Category {
    static let forest = Color.accentPrimary
    static let gold = Color(light: Color.Brand.gold600, dark: Color.Brand.gold400)
    static let clay = Color(light: Color.Brand.clay600, dark: Color(hex: "c49a7a"))
    static let slate = Color(light: Color.Brand.slate600, dark: Color.Brand.slate400)
  }

  // MARK: - Semantic Aliases
  enum Semantic {
    static let actionPrimary = Color.accentPrimary
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
  static let darkSlate = Color(light: Color.Brand.slate700, dark: Color.Brand.slate300)
  static let secondaryText = Color(light: Color.Brand.slate500, dark: Color.Brand.slate400)
  static let tertiaryText = Color(light: Color.Brand.slate600, dark: Color.Brand.slate400)
  static let nearBlack = Color(light: Color.Brand.slate900, dark: Color.Brand.slate50)
  /// Brand color for tints, links, icons and text. Dark mode lifts to forest-400
  /// (forest-600 fails AA on dark cards).
  static let accentPrimary = Color(light: Color.Brand.forest600, dark: Color.Brand.forest400)
  /// Solid fill behind white text (buttons, avatars). forest-500 in dark keeps white text at 4.9:1.
  static let accentFill = Color(light: Color.Brand.forest600, dark: Color.Brand.forest500)
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
  static let iconGray = Color(light: Color.Brand.slate500, dark: Color.Brand.slate400)
  static let borderGray = Color(light: Color.Brand.slate200, dark: Color.white.opacity(0.12))

  // MARK: - Surface Tokens
  // Warm stone neutrals on a cream page, mirroring web theme.css. Dark values are iOS-only
  // (web has no dark mode) and keep WCAG AA against the dark card.
  enum Surface {
    private static let warmInk = Color(red: 41 / 255, green: 37 / 255, blue: 36 / 255)

    static let background  = Color(light: Color(hex: "F5F5F0"), dark: Color(hex: "0C0A09"))  // page/screen background
    static let card        = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1C1917"))  // card / sheet background
    static let muted       = Color(light: Color(hex: "ECEBE5"), dark: Color(hex: "292524"))  // muted fills
    static let border      = Color(light: warmInk.opacity(0.12), dark: Color.white.opacity(0.1))
    static let borderStrong = Color(light: warmInk.opacity(0.22), dark: Color.white.opacity(0.2))
    // Brand-tinted banner (parent preview): forest-50 fill, forest-200 bottom border, forest-700 text.
    static let brandTint       = Color(light: Color.Brand.forest50, dark: Color.Brand.forest900)
    static let brandTintBorder = Color(light: Color.Brand.forest200, dark: Color.Brand.forest700)
    static let onBrandTint     = Color(light: Color.Brand.forest700, dark: Color.Brand.forest200)
    // Tinted status banners (e.g. ParentOnboardingBanner) — light tint on light mode, dark low-luminance tint on dark mode.
    static let warningTint   = Color(light: Color(hex: "FFFBEB"), dark: Color(hex: "3A2A0A"))
    static let warningAccent = Color(light: Color(hex: "F59E0B"), dark: Color(hex: "D97706"))
    static let warningCTA    = Color(light: Color(hex: "D97706"), dark: Color(hex: "F59E0B"))
    static let successTint   = Color(light: Color(hex: "F0FDF4"), dark: Color(hex: "0F2E1C"))
    static let successAccent = Color(light: Color(hex: "22C55E"), dark: Color(hex: "16A34A"))
  }

  // MARK: - Text Tokens
  enum Text {
    static let primary   = Color(light: Color.Brand.slate900, dark: Color.Brand.slate50)   // headings
    static let secondary = Color(light: Color.Brand.slate700, dark: Color.Brand.slate300)  // body copy
    static let muted     = Color(light: Color.Brand.slate500, dark: Color.Brand.slate400)  // captions, placeholder
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
