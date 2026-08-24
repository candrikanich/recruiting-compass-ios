import SwiftUI

/// Timeline "Guidance" tab — composes the 5 guidance widgets in the same order
/// as the web sidebar: what matters now, upcoming milestones, recruiting
/// calendar, common worries, and what not to stress about.
struct TimelineGuidanceView: View {
  let viewModel: TimelineViewModel
  let sport: String?
  let gender: String?
  let graduationYear: Int?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        WhatMattersNowWidget(
          items: viewModel.whatMattersItems,
          phaseLabel: viewModel.currentPhase.gradeLabel
        )
        UpcomingMilestonesWidget(sport: sport, gender: gender, graduationYear: graduationYear)
        RecruitingCalendarWidget(sport: sport, gender: gender, graduationYear: graduationYear)
        CommonWorriesWidget(phase: viewModel.currentPhase)
        WhatNotToStressWidget(phase: viewModel.currentPhase)
      }
      .padding(.horizontal)
      .padding(.vertical, 16)
    }
  }
}
