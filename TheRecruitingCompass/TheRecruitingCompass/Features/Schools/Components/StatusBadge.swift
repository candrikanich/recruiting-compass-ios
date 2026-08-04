import SwiftUI

struct StatusBadge: View {
  let status: SchoolStatus

  var body: some View {
    Text(status.displayName)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(status.badgeColor.backgroundColor)
      .foregroundStyle(status.badgeColor.foregroundColor)
      .clipShape(Capsule())
      .accessibilityLabel("Status: \(status.displayName)")
  }
}
