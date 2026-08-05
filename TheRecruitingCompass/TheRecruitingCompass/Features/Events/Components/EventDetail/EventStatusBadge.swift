import SwiftUI

struct EventStatusBadge: View {
  let registered: Bool
  let attended: Bool

  var body: some View {
    BadgeLabel(text: label, color: color)
  }

  private var label: String {
    if attended { return "Attended" }
    if registered { return "Registered" }
    return "Not Registered"
  }

  private var color: Color {
    if attended { return .green }
    if registered { return .blue }
    return .gray
  }
}
