import SwiftUI

struct CoachCardView: View {
  let coach: Coach
  let schoolName: String
  let onDelete: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

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
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(coach.fullName), \(coach.role.displayName) at \(schoolName), responsiveness \(Int(coach.responsivenessScore))%")
    .accessibilityHint("Double tap to view coach details")
  }

  // MARK: - Header

  private var headerSection: some View {
    HStack(spacing: 12) {
      initialsCircle
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

  private var initialsCircle: some View {
    Text(coach.initials)
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
      .clipShape(Circle())
  }

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
  }

  // MARK: - Content

  private var contentSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let email = coach.email {
        contactRow(icon: "envelope", text: email)
      }

      if let phone = coach.phone {
        contactRow(icon: "phone", text: phone)
      }

      ResponsivenessBar(score: coach.responsivenessScore)

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

  private var actionsSection: some View {
    HStack(spacing: 4) {
      communicationButtons

      Spacer()

      Button(role: .destructive) {
        onDelete()
      } label: {
        Image(systemName: "trash")
          .font(.system(size: sizeCategory.isAccessibilityCategory ? 20 : 16))
          .foregroundStyle(Color.errorRed)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Delete coach")
      .accessibilityHint("Shows delete confirmation")
    }
  }

  @ViewBuilder
  private var communicationButtons: some View {
    if let email = coach.email {
      CommunicationButton(type: .email(email), value: email)
    }
    if let phone = coach.phone {
      CommunicationButton(type: .phone(phone), value: phone)
    }
    if let twitter = coach.twitterHandle {
      CommunicationButton(type: .twitter(twitter), value: twitter)
    }
    if let instagram = coach.instagramHandle {
      CommunicationButton(type: .instagram(instagram), value: instagram)
    }
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
      responsivenessScore: 85,
      lastContactDate: "2026-01-15T10:00:00Z",
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-15T10:00:00Z"
    ),
    schoolName: "State University",
    onDelete: {}
  )
  .padding()
}
