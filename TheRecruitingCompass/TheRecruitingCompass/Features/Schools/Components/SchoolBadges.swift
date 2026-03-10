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

struct PriorityTierBadge: View {
  let tier: PriorityTier

  var body: some View {
    Text("Tier \(tier.displayName)")
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(tier.badgeColor.opacity(0.2))
      .foregroundStyle(tier.badgeColor)
      .clipShape(Capsule())
      .accessibilityLabel("Priority Tier \(tier.displayName)")
  }
}

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

struct SizeBadge: View {
  let size: SchoolSize

  var body: some View {
    Text(size.displayName)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color.gray.opacity(0.15))
      .foregroundStyle(.secondary)
      .clipShape(Capsule())
      .accessibilityLabel("Size: \(size.displayName)")
  }
}

struct ConferenceBadge: View {
  let conference: String

  var body: some View {
    Text(conference)
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color.gray.opacity(0.1))
      .foregroundStyle(.secondary)
      .clipShape(Capsule())
      .accessibilityLabel("Conference: \(conference)")
  }
}
