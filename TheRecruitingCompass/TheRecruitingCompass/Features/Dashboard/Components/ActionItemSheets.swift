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
/// Scopes the editor to the selected athlete so a parent viewing an athlete sees that
/// athlete's links, not an empty editor scoped to their own id. `userId` (the acting user)
/// is the self-viewing fallback. Parents and players collaborate on the same profile —
/// matches the Settings and Athletics-tab video-link entry points (family-shared profile,
/// see web issue #555).
struct ActionItemVideoLinksSheet: View {
  let userId: String
  var familyUnitId: String?
  @Environment(FamilyManager.self) private var familyManager

  var body: some View {
    NavigationStack {
      VideoLinksEditorView(
        athleteUserId: familyManager.selectedAthlete?.userId ?? userId,
        familyUnitId: familyUnitId,
        isReadOnly: false
      )
    }
  }
}
