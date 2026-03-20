import SwiftUI

struct SchoolCoachesPanel: View {
  let coaches: [Coach]
  let isLoading: Bool
  let onSeeAll: () -> Void

  private let maxDisplayedCoaches = 3

  private var displayedCoaches: [Coach] {
    Array(coaches.prefix(maxDisplayedCoaches))
  }

  private var hasMoreCoaches: Bool {
    coaches.count > maxDisplayedCoaches
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Coaches", systemImage: "person.2")
          .font(.headline)
          .foregroundStyle(.primary)

        Spacer()

        if hasMoreCoaches {
          Button(action: onSeeAll) {
            Text("See All (\(coaches.count))")
              .font(.subheadline)
              .foregroundStyle(Color.accentBlue)
          }
          .accessibilityLabel("See all \(coaches.count) coaches")
          .accessibilityHint("View complete list of coaches")
        }
      }

      if isLoading {
        HStack {
          Spacer()
          ProgressView()
            .accessibilityLabel("Loading coaches")
          Spacer()
        }
        .padding(.vertical, 20)
      } else if coaches.isEmpty {
        CoachesEmptyState()
      } else {
        VStack(spacing: 0) {
          ForEach(displayedCoaches) { coach in
            CompactCoachCard(coach: coach)

            if coach.id != displayedCoaches.last?.id {
              Divider()
                .accessibilityHidden(true)
            }
          }
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowMd()
  }
}

private struct CoachesEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "person.crop.circle.badge.questionmark")
        .font(.largeTitle)
        .imageScale(.large)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No Coaches Added")
        .font(.headline)
        .foregroundStyle(.secondary)

      Text("Add coaches to track your recruiting contacts")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No coaches added")
    .accessibilityHint("Use the manage coaches button to add recruiting contacts")
  }
}

#Preview("With Coaches") {
  SchoolCoachesPanel(
    coaches: [
      Coach(
        id: "1",
        firstName: "John",
        lastName: "Smith",
        email: "john@school.edu",
        phone: "555-1234",
        position: "head",
        schoolId: "school-1",
        twitterHandle: "@coach",
        instagramHandle: "@coach",
        notes: nil,
        lastContactDate: nil,
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
      ),
      Coach(
        id: "2",
        firstName: "Jane",
        lastName: "Doe",
        email: "jane@school.edu",
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
    ],
    isLoading: false,
    onSeeAll: {}
  )
  .padding()
}

#Preview("Loading") {
  SchoolCoachesPanel(
    coaches: [],
    isLoading: true,
    onSeeAll: {}
  )
  .padding()
}

#Preview("Empty") {
  SchoolCoachesPanel(
    coaches: [],
    isLoading: false,
    onSeeAll: {}
  )
  .padding()
}
