import SwiftUI

struct FamilyMemberCard: View {
  let member: FamilyMember
  let onRemove: () -> Void

  private static let isoParser: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let isoParserFallback: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  var body: some View {
    HStack(spacing: FamilyConstants.Spacing.small) {
      Circle()
        .fill(Color.blue.opacity(0.2))
        .frame(width: 44, height: 44)
        .overlay(
          Text(initials)
            .font(.headline)
            .foregroundStyle(.blue)
        )
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(displayName)
          .font(.headline)

        HStack(spacing: 8) {
          if member.isParent {
            Text("Parent")
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.green.opacity(0.2))
              .foregroundStyle(.green)
              .clipShape(.rect(cornerRadius: 4))
          }

          if let addedAt = member.addedAt,
             let date = FamilyMemberCard.isoParser.date(from: addedAt)
               ?? FamilyMemberCard.isoParserFallback.date(from: addedAt) {
            Text("Joined \(DateFormatter.memberJoinDate.string(from: date))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      Spacer()

      if member.isParent {
        Button(action: onRemove) {
          Image(systemName: "trash")
            .foregroundStyle(.red)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(removeAccessibilityLabel)
      }
    }
    .padding(FamilyConstants.Spacing.small)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(cardAccessibilityLabel)
  }

  var cardAccessibilityLabel: String {
    "\(displayName), \(member.role), joined \(formattedJoinDate)"
  }

  var removeAccessibilityLabel: String {
    "Remove \(displayName)"
  }

  var displayName: String {
    member.user?.fullName ?? member.user?.email ?? "Unknown"
  }

  private var initials: String {
    if let name = member.user?.fullName {
      let components = name.split(separator: " ")
      if components.count >= 2 {
        return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
      } else if let first = components.first {
        return String(first.prefix(2)).uppercased()
      }
    }
    if let email = member.user?.email {
      return String(email.prefix(2)).uppercased()
    }
    return "??"
  }

  var formattedJoinDate: String {
    guard let addedAt = member.addedAt,
          let date = FamilyMemberCard.isoParser.date(from: addedAt)
            ?? FamilyMemberCard.isoParserFallback.date(from: addedAt) else {
      return "recently"
    }
    return DateFormatter.memberJoinDate.string(from: date)
  }
}
