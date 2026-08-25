import SwiftUI

enum CoachCardVariant: Sendable {
  case compact
  case full
}

struct CoachCardView: View {
  let coach: Coach
  var variant: CoachCardVariant = .full
  /// Show the school logo + name subtitle. Only meaningful for `.full`
  /// (true in the cross-school directory, false in the same-school manage list).
  var showSchoolMeta: Bool = false
  var schoolName: String = ""
  var schoolLogoUrl: String?
  var schoolInitials: String = ""

  /// When set, email and text buttons open Quick Communication sheet instead of Mail/Messages.
  var onQuickCommunication: ((QuickCommunicationContext) -> Void)?

  var body: some View {
    switch variant {
    case .compact: compactBody
    case .full: fullBody
    }
  }

  // MARK: - Compact (school-sidebar): name + role badge + icons only

  @ViewBuilder private var compactBody: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(coach.fullName)
          .font(.body)
          .fontWeight(.medium)
          .foregroundStyle(.primary)

        Spacer()

        CoachCardRoleBadge(role: coach.role)
      }

      CoachCardActionsSection(coach: coach, schoolName: schoolName, onQuickCommunication: onQuickCommunication)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
  }

  // MARK: - Full (directory / manage): header + contact rows + icons

  @ViewBuilder private var fullBody: some View {
    VStack(alignment: .leading, spacing: 12) {
      CoachCardHeaderSection(
        coach: coach,
        showSchoolMeta: showSchoolMeta,
        schoolName: schoolName,
        schoolLogoUrl: schoolLogoUrl,
        schoolInitials: schoolInitials
      )
      CoachCardContentSection(coach: coach)
      CoachCardActionsSection(coach: coach, schoolName: schoolName, onQuickCommunication: onQuickCommunication)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(uiColor: .secondarySystemBackground))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(uiColor: .separator), lineWidth: 1)
    )
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityElement(children: .contain)
  }
}

// MARK: - Header

private struct CoachCardHeaderSection: View {
  let coach: Coach
  let showSchoolMeta: Bool
  let schoolName: String
  let schoolLogoUrl: String?
  let schoolInitials: String

  var body: some View {
    HStack(spacing: 12) {
      if showSchoolMeta {
        SchoolLogoAvatar(logoUrl: schoolLogoUrl, initials: schoolInitials)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(coach.fullName)
          .font(.headline)
          .foregroundStyle(.primary)

        if showSchoolMeta {
          Text(schoolName)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      CoachCardRoleBadge(role: coach.role)
    }
  }
}

private struct CoachCardRoleBadge: View {
  let role: CoachRole

  var body: some View {
    Text(role.displayName)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(role.badgeColor)
      .clipShape(Capsule())
      .accessibilityLabel(String(localized: "Role: \(role.displayName)"))
      .accessibilityAddTraits(.isStaticText)
  }
}

// MARK: - Content

private struct CoachCardContentSection: View {
  let coach: Coach

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let email = coach.contactEmail {
        contactRow(icon: "envelope", text: email)
      }

      if let phone = coach.contactPhone {
        contactRow(icon: "phone", text: phone)
      }

      if let lastContact = coach.lastContactDateParsed {
        lastContactRow(date: lastContact)
      }
    }
  }
}

private func contactRow(icon: String, text: String) -> some View {
  HStack(spacing: 8) {
    Image(systemName: icon)
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(width: 16)
      .accessibilityHidden(true)

    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }
}

private func lastContactRow(date: Date) -> some View {
  HStack(spacing: 8) {
    Image(systemName: "clock")
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(width: 16)
      .accessibilityHidden(true)

    Text("Last contact: \(date, style: .relative) ago")
      .font(.caption)
      .foregroundStyle(Color.tertiaryText)
  }
}

// MARK: - Actions (canonical 5: Email, Text, Call, X, Instagram)

private struct CoachCardActionsSection: View {
  let coach: Coach
  let schoolName: String
  var onQuickCommunication: ((QuickCommunicationContext) -> Void)?

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    HStack(spacing: 4) {
      if let email = coach.contactEmail {
        if let onQuickCommunication {
          quickCommunicationTriggerButton(
            icon: "envelope.fill",
            color: Color.accentBlue,
            label: String(localized: "Email coach"),
            hint: "Opens Quick Communication with templates"
          ) {
            onQuickCommunication(QuickCommunicationContext(coach: coach, schoolName: schoolName))
          }
        } else {
          CommunicationButton(type: .email(email), value: email)
        }
      }

      if let phone = coach.contactPhone {
        if let onQuickCommunication {
          quickCommunicationTriggerButton(
            icon: "message.fill",
            color: .successGreen,
            label: String(localized: "Text coach"),
            hint: "Opens Quick Communication with templates"
          ) {
            onQuickCommunication(QuickCommunicationContext(coach: coach, schoolName: schoolName))
          }
        } else {
          CommunicationButton(type: .phone(phone), value: phone)
        }

        // Call is always the OS dialer, never the Quick Communication modal.
        CommunicationButton(type: .call(phone), value: phone)
      }

      if let twitter = coach.contactTwitter {
        CommunicationButton(type: .twitter(twitter), value: twitter)
      }

      if let instagram = coach.contactInstagram {
        CommunicationButton(type: .instagram(instagram), value: instagram)
      }

      Spacer()
    }
  }

  private func quickCommunicationTriggerButton(
    icon: String,
    color: Color,
    label: String,
    hint: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: sizeCategory.isAccessibilityCategory ? 24 : 18))
        .foregroundStyle(color)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(label)
    .accessibilityHint(hint)
  }
}

#Preview("Full — directory (school meta)") {
  CoachCardView(
    coach: Coach(
      id: "1",
      firstName: "John",
      lastName: "Smith",
      email: "john@university.edu",
      phone: "555-0123",
      position: "head",
      schoolId: "school-1",
      twitterHandle: "@coachsmith",
      instagramHandle: "@coachsmith",
      notes: "Great recruiter",
      lastContactDate: "2026-01-15T10:00:00Z",
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-15T10:00:00Z"
    ),
    variant: .full,
    showSchoolMeta: true,
    schoolName: "State University",
    schoolLogoUrl: nil,
    schoolInitials: "SU"
  )
  .padding()
}

#Preview("Compact — school sidebar") {
  CoachCardView(
    coach: Coach(
      id: "2",
      firstName: "Jane",
      lastName: "Doe",
      email: "jane@university.edu",
      phone: "555-0199",
      position: "assistant",
      schoolId: "school-1",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      lastContactDate: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-15T10:00:00Z"
    ),
    variant: .compact
  )
  .padding()
}
