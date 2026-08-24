import SwiftUI

/// Timeline "Guidance" tab — composes the 4 guidance widgets in the same order
/// as the web sidebar: what matters now, recruiting calendar (which carries
/// its own rich upcoming-milestones list), common worries, and what not to
/// stress about. Each is wrapped in a `CollapsibleSection` so all 4 render at
/// equal width and collapse independently (web defaults: What Matters open,
/// rest collapsed).
struct TimelineGuidanceView: View {
  let viewModel: TimelineViewModel
  let sport: String?
  let gender: String?
  let graduationYear: Int?
  let onSelectTask: (String) -> Void

  @State private var whatMattersExpanded = true
  @State private var calendarExpanded = false
  @State private var worriesExpanded = false
  @State private var stressExpanded = false

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        CollapsibleSection(
          title: String(localized: "⚡ What Matters Right Now"),
          isExpanded: whatMattersExpanded,
          onToggle: { whatMattersExpanded.toggle() }
        ) {
          WhatMattersNowWidget(
            items: viewModel.whatMattersItems,
            phaseLabel: viewModel.currentPhase.gradeLabel,
            onSelectTask: onSelectTask
          )
        }

        CollapsibleSection(
          title: String(localized: "📆 Recruiting Calendar"),
          isExpanded: calendarExpanded,
          onToggle: { calendarExpanded.toggle() }
        ) {
          RecruitingCalendarWidget(
            sport: sport,
            gender: gender,
            graduationYear: graduationYear,
            showHeader: false
          )
        }

        CollapsibleSection(
          title: String(localized: "❓ Common Worries"),
          isExpanded: worriesExpanded,
          onToggle: { worriesExpanded.toggle() }
        ) {
          CommonWorriesWidget(phase: viewModel.currentPhase)
        }

        CollapsibleSection(
          title: String(localized: "🛡️ What NOT to Stress About"),
          isExpanded: stressExpanded,
          onToggle: { stressExpanded.toggle() }
        ) {
          WhatNotToStressWidget(phase: viewModel.currentPhase)
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 16)
    }
  }
}
