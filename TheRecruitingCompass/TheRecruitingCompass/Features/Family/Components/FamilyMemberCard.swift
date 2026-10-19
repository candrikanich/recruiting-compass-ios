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
    VStack(alignment: .leading, spacing: 4) {
      row
      if let blockedReason {
        Text(blockedReason)
          .font(.brand(.caption))
          .foregroundStyle(.secondary)
      }
    }
    .padding(FamilyConstants.Spacing.small)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var row: some View {
    HStack(spacing: FamilyConstants.Spacing.small) {
      memberInfo
      Spacer()
      removeButton
    }
  }

  /// Name, role and join date read as one element. The Remove button and the server's reason stay separate
  /// elements so VoiceOver can reach the button and read why it is disabled.
  @ViewBuilder
  private var memberInfo: some View {
    HStack(spacing: FamilyConstants.Spacing.small) {
      Circle()
        .fill(Color.accentPrimary.opacity(0.2))
        .frame(width: 44, height: 44)
        .overlay(
          Text(initials)
            .font(.brand(.headline))
            .foregroundStyle(Color.accentPrimary)
        )
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(displayName)
          .font(.brand(.headline))

        HStack(spacing: 8) {
          if member.isParent {
            Text("Parent")
              .font(.brand(.caption))
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
              .font(.brand(.caption))
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(cardAccessibilityLabel)
  }

  @ViewBuilder
  private var removeButton: some View {
    Group {
      if removeControl.isVisible {
        Button(action: onRemove) {
          Image(systemName: "trash")
            .foregroundStyle(removeControl.isEnabled ? Color.red : Color.secondary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(!removeControl.isEnabled)
        .accessibilityLabel(removeAccessibilityLabel)
        .accessibilityHint(removeControl.reason ?? "")
      }
    }
  }

  /// The server's explanation for a disabled Remove; shown under the row, never computed here.
  var blockedReason: String? { removeControl.reason }

  /// What the Remove control looks like. Only the server's verdict enables it; no verdict hides it.
  var removeControl: ServerControl {
    ServerControl(allowed: member.canRemove, blockedReason: member.removeBlockedReason)
  }

  var cardAccessibilityLabel: String {
    String(localized: "\(displayName), \(member.role), joined \(formattedJoinDate)")
  }

  var removeAccessibilityLabel: String {
    String(localized: "Remove \(displayName)")
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
