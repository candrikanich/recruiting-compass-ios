import SwiftUI

struct CompactCoachCard: View {
  let coach: Coach

  @Environment(\.sizeCategory) private var sizeCategory

  private var avatarSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 48 : 40
  }

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(coach.role.badgeColor.opacity(0.2))
        .frame(width: avatarSize, height: avatarSize)
        .overlay {
          Text(coach.initials)
            .font(.system(size: avatarSize * 0.4, weight: .semibold))
            .foregroundStyle(coach.role.badgeColor)
        }
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(coach.fullName)
            .font(.body)
            .fontWeight(.medium)

          RoleBadge(role: coach.role)
        }

        if let email = coach.email {
          Text(email)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      HStack(spacing: 4) {
        if let email = coach.email {
          CommunicationButton(type: .email(email), value: email)
        }

        if let phone = coach.phone {
          CommunicationButton(type: .phone(phone), value: phone)
          CommunicationButton(type: .call(phone), value: phone)
        }

        if let twitter = coach.twitterHandle {
          CommunicationButton(type: .twitter(twitter), value: twitter)
        }

        if let instagram = coach.instagramHandle {
          CommunicationButton(type: .instagram(instagram), value: instagram)
        }
      }
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(coach.fullName), \(coach.role.displayName)")
    .accessibilityHint(email: coach.email)
  }
}

private struct RoleBadge: View {
  let role: CoachRole

  var body: some View {
    Text(role.displayName)
      .font(.caption2)
      .fontWeight(.medium)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(role.badgeColor.opacity(0.15))
      .foregroundStyle(role.badgeColor)
      .cornerRadius(4)
  }
}

private extension View {
  func accessibilityHint(email: String?) -> some View {
    if let email {
      return self.accessibilityHint("Email: \(email). Use communication buttons to contact.")
    } else {
      return self.accessibilityHint("Use communication buttons to contact.")
    }
  }
}

#Preview("Single Coach") {
  CompactCoachCard(
    coach: Coach(
      id: "1",
      firstName: "John",
      lastName: "Smith",
      email: "john.smith@school.edu",
      phone: "555-1234",
      position: "head",
      schoolId: "school-1",
      twitterHandle: "@coachsmith",
      instagramHandle: "@coachsmith",
      notes: nil,
      privateNotes: nil,
      responsivenessScore: 0.85,
      lastContactDate: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  )
  .padding()
}

#Preview("Coach Without Social") {
  CompactCoachCard(
    coach: Coach(
      id: "2",
      firstName: "Jane",
      lastName: "Doe",
      email: "jane.doe@school.edu",
      phone: nil,
      position: "assistant",
      schoolId: "school-1",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      privateNotes: nil,
      responsivenessScore: 0.70,
      lastContactDate: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  )
  .padding()
}
