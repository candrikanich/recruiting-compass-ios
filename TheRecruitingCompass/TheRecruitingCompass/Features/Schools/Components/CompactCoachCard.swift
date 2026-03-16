import SwiftUI

struct CompactCoachCard: View {
  let coach: Coach

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Row 1: Coach Name – Role
      Text("\(coach.fullName) – \(coach.role.displayName)")
        .font(.body)
        .fontWeight(.medium)
        .foregroundStyle(.primary)

      // Row 2: Communication icons
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

      // Row 3: Date of last contact
      if let lastContact = coach.lastContactDateParsed {
        Text("Last contact: \(lastContact, format: .relative(presentation: .named))")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text("Last contact: —")
          .font(.caption)
          .foregroundStyle(Color.tertiaryText)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabelText)
    .accessibilityHint("Use communication buttons to contact")
  }

  private var accessibilityLabelText: String {
    var parts = [coach.fullName, coach.role.displayName]
    if let lastContact = coach.lastContactDateParsed {
      parts.append("Last contacted \(lastContact.formatted(date: .abbreviated, time: .omitted))")
    } else {
      parts.append("Not yet contacted")
    }
    return parts.joined(separator: ", ")
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
      lastContactDate: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  )
  .padding()
}

#Preview("Coach With Last Contact") {
  CompactCoachCard(
    coach: Coach(
      id: "3",
      firstName: "Mike",
      lastName: "Roberts",
      email: "mroberts@school.edu",
      phone: "555-9999",
      position: "head",
      schoolId: "school-1",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      lastContactDate: "2026-02-20T14:00:00Z",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2026-02-20T14:00:00Z"
    )
  )
  .padding()
}
