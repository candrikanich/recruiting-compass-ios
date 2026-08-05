import SwiftUI

/// Contact information section for coach detail view.
struct ContactInfoSection: View {
  let coach: Coach
  /// When set, email row opens Quick Communication instead of Mail.
  var onEmailTap: (() -> Void)?
  /// When set, phone row opens Quick Communication instead of Messages.
  var onPhoneTap: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Contact Information")

      if let email = coach.email {
        ContactRow(
          icon: "envelope",
          label: String(localized: "Email"),
          value: email,
          type: .email(email),
          customAction: onEmailTap
        )
      }

      if let phone = coach.phone {
        ContactRow(
          icon: "phone",
          label: String(localized: "Phone"),
          value: phone,
          type: .phone(phone),
          customAction: onPhoneTap
        )
      }

      if let twitter = coach.twitterHandle {
        ContactRow(icon: "at", label: String(localized: "Twitter"), value: twitter, type: .twitter(twitter))
      }

      if let instagram = coach.instagramHandle {
        ContactRow(icon: "camera", label: String(localized: "Instagram"), value: instagram, type: .instagram(instagram))
      }
    }
  }
}

#Preview {
  ContactInfoSection(
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
    )
  )
  .padding()
}
