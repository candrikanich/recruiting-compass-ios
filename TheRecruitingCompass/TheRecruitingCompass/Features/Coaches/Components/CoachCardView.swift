import SwiftUI

struct CoachCardView: View {
  let coach: Coach
  let schoolName: String
  let schoolLogoUrl: String?
  let schoolInitials: String

  /// When set, email and phone buttons open Quick Communication sheet instead of Mail/Messages.
  var onQuickCommunication: ((QuickCommunicationContext) -> Void)?
  var onDelete: () -> Void = {}

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.sizeCategory) private var sizeCategory

  var deleteAccessibilityLabel: String { "Delete \(coach.fullName)" }

  private var initialsSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  private var initialsFont: Font {
    sizeCategory.isAccessibilityCategory ? .title2.bold() : .body.bold()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      headerSection
      contentSection
      actionsSection
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(uiColor: .secondarySystemBackground))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityElement(children: .contain)
  }

  // MARK: - Header

  @ViewBuilder
  private var headerSection: some View {
    HStack(spacing: 12) {
      schoolLogoView
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(coach.fullName)
          .font(.headline)
          .foregroundStyle(.primary)

        Text(schoolName)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      roleBadge
    }
  }

  @ViewBuilder
  private var schoolLogoView: some View {
    if let faviconUrl = schoolLogoUrl, let url = URL(string: faviconUrl) {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFit()
        case .failure, .empty:
          initialsCircle
        @unknown default:
          initialsCircle
        }
      }
      .frame(width: initialsSize, height: initialsSize)
      .clipShape(RoundedRectangle(cornerRadius: 10))
    } else {
      initialsCircle
    }
  }

  @ViewBuilder
  private var initialsCircle: some View {
    Text(schoolInitials)
      .font(initialsFont)
      .foregroundStyle(.white)
      .frame(width: initialsSize, height: initialsSize)
      .background(
        LinearGradient(
          colors: [.blueGradientStart, Color(hex: "7C3AED")],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  @ViewBuilder
  private var roleBadge: some View {
    Text(coach.role.displayName)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(coach.role.badgeColor)
      .clipShape(Capsule())
      .accessibilityLabel("Role: \(coach.role.displayName)")
      .accessibilityAddTraits(.isStaticText)
  }

  // MARK: - Content

  @ViewBuilder
  private var contentSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let email = coach.email {
        contactRow(icon: "envelope", text: email)
      }

      if let phone = coach.phone {
        contactRow(icon: "phone", text: phone)
      }

      if let lastContact = coach.lastContactDateParsed {
        lastContactRow(date: lastContact)
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

  // MARK: - Actions

  @ViewBuilder
  private var actionsSection: some View {
    HStack(spacing: 4) {
      communicationButtons

      Spacer()

      deleteButton
    }
  }

  @ViewBuilder
  private var deleteButton: some View {
    Button(role: .destructive, action: onDelete) {
      Image(systemName: "trash")
        .font(.subheadline)
        .foregroundStyle(Color.errorRed)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(deleteAccessibilityLabel)
    .accessibilityHint("Double tap to delete this coach")
  }

  @ViewBuilder
  private var communicationButtons: some View {
    if let email = coach.email {
      if let onQuickCommunication {
        quickCommunicationTriggerButton(
          icon: "envelope.fill",
          color: Color.accentBlue,
          label: "Email coach",
          hint: "Opens Quick Communication with templates"
        ) {
          onQuickCommunication(QuickCommunicationContext(coach: coach, schoolName: schoolName))
        }
      } else {
        CommunicationButton(type: .email(email), value: email)
      }
    }
    if let phone = coach.phone {
      if let onQuickCommunication {
        quickCommunicationTriggerButton(
          icon: "message.fill",
          color: .successGreen,
          label: "Text coach",
          hint: "Opens Quick Communication with templates"
        ) {
          onQuickCommunication(QuickCommunicationContext(coach: coach, schoolName: schoolName))
        }
      } else {
        CommunicationButton(type: .phone(phone), value: phone)
      }
    }
    if let twitter = coach.twitterHandle {
      CommunicationButton(type: .twitter(twitter), value: twitter)
    }
    if let instagram = coach.instagramHandle {
      CommunicationButton(type: .instagram(instagram), value: instagram)
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

#Preview {
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
    schoolName: "State University",
    schoolLogoUrl: nil,
    schoolInitials: "SU"
  )
  .padding()
}
