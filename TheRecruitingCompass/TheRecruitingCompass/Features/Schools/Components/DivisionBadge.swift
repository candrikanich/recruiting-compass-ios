import SwiftUI

struct DivisionBadge: View {
  let division: String

  private var badgeColor: BadgeColor {
    Division(rawValue: division.uppercased())?.badgeColor ?? .slate
  }

  var body: some View {
    Text(division.uppercased())
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(badgeColor.backgroundColor)
      .foregroundStyle(badgeColor.foregroundColor)
      .clipShape(Capsule())
      .accessibilityLabel("Division: \(division)")
  }
}
