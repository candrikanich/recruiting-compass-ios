import SwiftUI

/// Presents the Add School flow in its own navigation stack (for action-item CTAs).
/// Mirrors DashboardView's DashboardAddSchoolSheet so it can be reused from the card.
struct ActionItemAddSchoolSheet: View {
  let familyUnitId: String
  let userId: String

  @State private var navigationPath = NavigationPath()

  var body: some View {
    NavigationStack(path: $navigationPath) {
      AddSchoolView(
        schoolsService: SchoolsServiceImpl(supabaseManager: .shared),
        familyUnitId: familyUnitId,
        userId: userId,
        navigationPath: $navigationPath
      )
      .navigationDestination(for: SchoolDestination.self) { destination in
        if case .detail(let schoolId) = destination {
          SchoolDetailView(schoolId: schoolId)
        }
      }
    }
  }
}

/// Presents the Log Interaction flow in its own navigation stack (for action-item CTAs).
struct ActionItemAddInteractionSheet: View {
  let familyUnitId: String
  let userId: String

  var body: some View {
    NavigationStack {
      AddInteractionView(
        interactionsService: InteractionsServiceImpl(supabaseManager: .shared),
        familyUnitId: familyUnitId,
        userId: userId
      )
    }
  }
}

/// Presents the video-links editor in its own navigation stack (for action-item CTAs).
/// `userId` is the acting user's id; for a player acting on their own suggestion this
/// IS the athlete, so it's passed as `athleteUserId`.
struct ActionItemVideoLinksSheet: View {
  let userId: String
  var familyUnitId: String?

  var body: some View {
    NavigationStack {
      VideoLinksEditorView(athleteUserId: userId, familyUnitId: familyUnitId, isReadOnly: false)
    }
  }
}
