import SwiftUI

struct ActivityNavigationModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .navigationDestination(for: ActivityDestination.self) { destination in
        switch destination.eventType {
        case .interaction, .schoolStatusChange:
          if let entityId = destination.entityId {
            SchoolDetailView(schoolId: entityId)
          }
        case .documentUpload:
          EmptyView()
        }
      }
      .navigationDestination(for: ActivityFeedDestination.self) { destination in
        switch destination {
        case .fullPage:
          ActivityFeedView()
        }
      }
  }
}

extension View {
  func activityNavigation() -> some View {
    modifier(ActivityNavigationModifier())
  }
}
