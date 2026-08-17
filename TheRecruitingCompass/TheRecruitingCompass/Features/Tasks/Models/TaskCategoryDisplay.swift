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
    case "academic": return Color.Brand.blue600
    case "athletic": return Color.Brand.purple600
    case "recruiting": return Color.Brand.emerald600
    case "exposure": return Color.Brand.orange600
    case "mindset": return Color.Brand.pink500
    default: return .secondary
    }
  }
}
