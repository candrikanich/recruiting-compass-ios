import SwiftUI

struct EventStatusBadge: View {
  let registered: Bool
  let attended: Bool

  var body: some View {
    BadgeLabel(text: label, color: color)
  }

  private var label: String {
    if attended { return String(localized: "Attended") }
    if registered { return String(localized: "Registered") }
    return String(localized: "Not Registered")
  }

  private var color: Color {
    if attended { return .green }
    if registered { return .blue }
    return .gray
  }
}
