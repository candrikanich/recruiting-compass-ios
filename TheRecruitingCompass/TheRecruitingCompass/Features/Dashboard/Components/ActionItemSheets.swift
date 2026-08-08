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
