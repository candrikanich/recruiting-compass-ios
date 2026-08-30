import SwiftUI

/// iPad-regular-width sidebar for `SchoolDetailView` — status, quick actions, coaches, fit,
/// and attribution, matching web's `SchoolSidebar`. On compact widths `AdaptiveDetailLayout`
/// stacks this beneath the main content instead of showing a separate column.
struct SchoolDetailSidebar: View {
  let school: School
  let viewModel: SchoolDetailViewModel
  let onLogInteraction: () -> Void
  let onSendEmail: () -> Void
  let onManageCoaches: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      SchoolRecruitingStatusAndTierSection(
        currentStatus: SchoolStatus(rawValue: school.status) ?? .interested,
        isUpdatingStatus: viewModel.isUpdatingStatus,
        onStatusChange: { await viewModel.updateStatus(to: $0) }
      )

      SchoolQuickActions(
        onLogInteraction: onLogInteraction,
        onSendEmail: onSendEmail,
        onManageCoaches: onManageCoaches
      )

      SchoolCoachesPanel(
        coaches: viewModel.coaches,
        isLoading: viewModel.isLoadingCoaches,
        onSeeAll: onManageCoaches
      )

      SchoolFitSection(
        personalFit: viewModel.personalFit,
        academicFit: viewModel.academicFit,
        isEnriching: viewModel.isEnriching,
        enrichError: viewModel.enrichError,
        onLookup: { Task { await viewModel.lookupAcademicData() } }
      )

      SchoolAttributionSection(
        createdBy: school.createdBy,
        createdAt: school.createdAt,
        updatedBy: school.updatedBy,
        updatedAt: school.updatedAt
      )
    }
  }
}
