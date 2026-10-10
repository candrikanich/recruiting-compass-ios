import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Barlow (body) and Barlow Semi Condensed (display), bundled under SIL OFL (Resources/Fonts/OFL.txt).
/// Registered in both Config/Info.plist and Config/Info-Release.plist; a missing Release entry silently
/// falls back to the system font on TestFlight.
enum BrandFont {
  /// Display face for the large styles, body face for everything else (web: `--font-display` / `--font-sans`).
  static func usesDisplayFace(_ style: Font.TextStyle) -> Bool {
    switch style {
    case .largeTitle, .title, .title2, .title3: return true
    default: return false
    }
  }

  /// Apple's default point sizes per text style; custom fonts scale from these with Dynamic Type.
  static func baseSize(_ style: Font.TextStyle) -> CGFloat {
    switch style {
    case .largeTitle: return 34
    case .title: return 28
    case .title2: return 22
    case .title3: return 20
    case .headline, .body: return 17
    case .callout: return 16
    case .subheadline: return 15
    case .footnote: return 13
    case .caption: return 12
    case .caption2: return 11
    @unknown default: return 17
    }
  }

  /// Web ships body 400/500/600 and display 500/600/700, so heavier weights clamp to the heaviest face.
  static func postScriptName(_ style: Font.TextStyle, weight: Font.Weight) -> String {
    if usesDisplayFace(style) {
      switch weight {
      case .bold, .heavy, .black: return "BarlowSemiCondensed-Bold"
      case .semibold: return "BarlowSemiCondensed-SemiBold"
      default: return "BarlowSemiCondensed-Medium"
      }
    }
    switch weight {
    case .semibold, .bold, .heavy, .black: return "Barlow-SemiBold"
    case .medium: return "Barlow-Medium"
    default: return "Barlow-Regular"
    }
  }

  static func defaultWeight(_ style: Font.TextStyle) -> Font.Weight {
    style == .headline ? .semibold : .regular
  }

  #if canImport(UIKit)
  static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
    switch style {
    case .largeTitle: return .largeTitle
    case .title: return .title1
    case .title2: return .title2
    case .title3: return .title3
    case .headline: return .headline
    case .callout: return .callout
    case .subheadline: return .subheadline
    case .footnote: return .footnote
    case .caption: return .caption1
    case .caption2: return .caption2
    default: return .body
    }
  }

  /// Dynamic Type-scaled UIKit font, used for navigation bar titles.
  static func uiFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> UIFont {
    let resolved = weight ?? defaultWeight(style)
    let size = baseSize(style)
    let base = UIFont(name: postScriptName(style, weight: resolved), size: size)
      ?? UIFont.systemFont(ofSize: size)
    return UIFontMetrics(forTextStyle: uiTextStyle(style)).scaledFont(for: base)
  }

  /// Applies Barlow to navigation bar titles once at app start.
  @MainActor
  static func configureNavigationBarAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithDefaultBackground()
    appearance.largeTitleTextAttributes = [.font: uiFont(.largeTitle, weight: .semibold)]
    appearance.titleTextAttributes = [.font: uiFont(.headline)]
    let proxy = UINavigationBar.appearance()
    proxy.standardAppearance = appearance
    proxy.scrollEdgeAppearance = appearance
    proxy.compactAppearance = appearance
  }
  #endif
}

extension Font {
  /// Barlow Semi Condensed for display styles, Barlow for everything else; scales with Dynamic Type.
  static func brand(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
    let resolved = weight ?? BrandFont.defaultWeight(style)
    return .custom(
      BrandFont.postScriptName(style, weight: resolved),
      size: BrandFont.baseSize(style),
      relativeTo: style
    )
  }
}
