import SwiftUI

struct DirectionBadge: View {
  let direction: Direction

  var body: some View {
    Text(direction.displayName)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundStyle(direction.badgeColor.foregroundColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(direction.badgeColor.backgroundColor)
      .clipShape(.rect(cornerRadius: 6))
  }
}
