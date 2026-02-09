import SwiftUI

struct CoachDetailView: View {
  let coachId: String
  let allCoaches: [Coach]
  let allSchools: [School]

  @StateObject private var viewModel: CoachDetailViewModel
  @Environment(\.sizeCategory) private var sizeCategory

  init(coachId: String, allCoaches: [Coach] = [], allSchools: [School] = []) {
    self.coachId = coachId
    self.allCoaches = allCoaches
    self.allSchools = allSchools
    _viewModel = StateObject(wrappedValue: CoachDetailViewModel(
      coachId: coachId,
      allCoaches: allCoaches,
      allSchools: allSchools
    ))
  }

  var body: some View {
    ScrollView {
      if viewModel.isLoading {
        loadingView
      } else if let coach = viewModel.coach {
        detailContent(coach: coach)
      } else if let error = viewModel.errorMessage {
        errorView(message: error)
      }
    }
    .navigationTitle("Coach Details")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await viewModel.loadCoach()
    }
  }

  // MARK: - Loading

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .accessibilityLabel("Loading coach details")
      Text("Loading...")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.top, 100)
  }

  // MARK: - Content

  private func detailContent(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      headerSection(coach: coach)
      contactInfoSection(coach: coach)
      statisticsSection(coach: coach)
      notesSection(coach: coach)
    }
    .padding()
  }

  private func headerSection(coach: Coach) -> some View {
    VStack(spacing: 16) {
      // Large initials circle
      Text(coach.initials)
        .font(.system(size: sizeCategory.isAccessibilityCategory ? 40 : 48).bold())
        .foregroundStyle(.white)
        .frame(width: sizeCategory.isAccessibilityCategory ? 120 : 100,
               height: sizeCategory.isAccessibilityCategory ? 120 : 100)
        .background(
          LinearGradient(
            colors: [.blueGradientStart, Color(hex: "7C3AED")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .clipShape(Circle())
        .accessibilityHidden(true)

      Text(coach.fullName)
        .font(.title2.bold())
        .accessibilityAddTraits(.isHeader)

      HStack(spacing: 8) {
        Text(coach.role.displayName)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(coach.role.badgeColor)
          .clipShape(Capsule())
          .accessibilityLabel("Role: \(coach.role.displayName)")

        if let school = viewModel.school {
          Text(school.name)
            .font(.subheadline)
            .foregroundStyle(Color.accentBlue)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func contactInfoSection(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "Contact Information")

      if let email = coach.email {
        contactRow(icon: "envelope", label: "Email", value: email, type: .email(email))
      }

      if let phone = coach.phone {
        contactRow(icon: "phone", label: "Phone", value: phone, type: .phone(phone))
      }

      if let twitter = coach.twitterHandle {
        contactRow(icon: "at", label: "Twitter", value: twitter, type: .twitter(twitter))
      }

      if let instagram = coach.instagramHandle {
        contactRow(icon: "camera", label: "Instagram", value: instagram, type: .instagram(instagram))
      }
    }
  }

  private func statisticsSection(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "Statistics")

      ResponsivenessBar(score: coach.responsivenessScore)
        .padding(.vertical, 4)

      if let lastContact = coach.lastContactDateParsed {
        HStack(spacing: 8) {
          Image(systemName: "clock")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
          Text("Last contacted \(lastContact, style: .relative) ago")
            .font(.subheadline)
        }
      } else {
        HStack(spacing: 8) {
          Image(systemName: "clock")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
          Text("Never contacted")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .italic()
        }
      }
    }
  }

  private func notesSection(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "Notes")

      if let notes = coach.notes, !notes.isEmpty {
        Text(notes)
          .font(.body)
          .foregroundStyle(.primary)
      } else {
        Text("No notes")
          .font(.body)
          .foregroundStyle(.secondary)
          .italic()
      }
    }
  }

  // MARK: - Helpers

  private func sectionHeader(title: String) -> some View {
    Text(title)
      .font(.headline)
      .foregroundStyle(.primary)
      .accessibilityAddTraits(.isHeader)
  }

  @ViewBuilder
  private func contactRow(icon: String, label: String, value: String, type: CommunicationType) -> some View {
    if let url = type.url(for: value) {
      Link(destination: url) {
        HStack(spacing: 12) {
          Image(systemName: icon)
            .font(.body)
            .foregroundStyle(type.iconColor)
            .frame(width: 24)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 2) {
            Text(label)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(value)
              .font(.body)
              .foregroundStyle(.primary)
          }

          Spacer()

          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }
      .accessibilityLabel("\(label): \(value)")
      .accessibilityHint("Opens \(type.appName)")
    } else {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.body)
          .foregroundStyle(.secondary)
          .frame(width: 24)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
          Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(value)
            .font(.body)
        }
      }
    }
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(Color.errorRed)
        .accessibilityHidden(true)
      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .padding(.top, 100)
  }
}

#Preview {
  NavigationStack {
    CoachDetailView(
      coachId: "1",
      allCoaches: [
        Coach(
          id: "1",
          firstName: "John",
          lastName: "Smith",
          email: "john@university.edu",
          phone: "555-0123",
          position: "head",
          schoolId: "school-1",
          twitterHandle: "@coachsmith",
          instagramHandle: "@coachsmith",
          notes: "Great recruiter, very responsive",
          responsivenessScore: 85,
          lastContactDate: "2026-01-15T10:00:00Z",
          createdAt: "2025-01-01T00:00:00Z",
          updatedAt: "2026-01-15T10:00:00Z"
        )
      ],
      allSchools: [
        School(
          id: "school-1",
          userId: "user-1",
          name: "State University",
          location: "State College, PA",
          city: "State College",
          state: "PA",
          division: "D1",
          conference: "Big Ten",
          ranking: 25,
          isFavorite: false,
          website: nil,
          faviconUrl: nil,
          twitterHandle: nil,
          instagramHandle: nil,
          ncaaId: nil,
          status: "interested",
          statusChangedAt: nil,
          priorityTier: "A",
          notes: nil,
          pros: [],
          cons: [],
          offerDetails: nil,
          academicInfo: nil,
          amenities: nil,
          coachingPhilosophy: nil,
          coachingStyle: nil,
          recruitingApproach: nil,
          communicationStyle: nil,
          successMetrics: nil,
          fitScore: nil,
          fitTier: nil,
          familyUnitId: "family-1",
          createdBy: nil,
          updatedBy: nil,
          createdAt: "2025-01-01T00:00:00Z",
          updatedAt: "2025-01-01T00:00:00Z"
        )
      ]
    )
  }
}
