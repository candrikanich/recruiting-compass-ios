import SwiftUI

/// Presentation for a task's `category` string, mirroring the web app's
/// category badge labels and colors (see web utils/taskHelpers.ts).
extension TaskWithStatus {
  var categoryLabel: String {
    switch category.lowercased() {
    case "academic": return String(localized: "Academic")
    case "athletic": return String(localized: "Athletic")
    case "recruiting": return String(localized: "Recruiting")
    case "exposure": return String(localized: "Exposure")
    case "mindset": return String(localized: "Mindset")
    default: return category.capitalized
    }
  }

  var categoryColor: Color {
    switch category.lowercased() {
    case "academic": return Color.Category.forest
    case "athletic": return Color.Category.gold
    case "recruiting": return Color.Category.clay
    case "exposure": return Color.Category.slate
    case "mindset": return Color(light: Color.Brand.forest500, dark: Color.Brand.forest300)
    default: return .secondary
    }
  }
}
