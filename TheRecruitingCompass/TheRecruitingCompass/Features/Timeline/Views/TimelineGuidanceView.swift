import SwiftUI

/// Timeline "Guidance" tab — composes the 5 guidance widgets in the same order
/// as the web sidebar: what matters now, upcoming milestones, recruiting
/// calendar, common worries, and what not to stress about. Each is wrapped in
/// a `CollapsibleSection` so all 5 render at equal width and collapse
/// independently (web defaults: What Matters open, rest collapsed).
struct TimelineGuidanceView: View {
  let viewModel: TimelineViewModel
  let sport: String?
  let gender: String?
  let graduationYear: Int?
  let onSelectTask: (String) -> Void

  @State private var whatMattersExpanded = true
  @State private var milestonesExpanded = false
  @State private var calendarExpanded = false
  @State private var worriesExpanded = false
  @State private var stressExpanded = false

  private static let todayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

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
          title: String(localized: "📅 Upcoming Milestones"),
          isExpanded: milestonesExpanded,
          onToggle: { milestonesExpanded.toggle() }
        ) {
          UpcomingMilestonesWidget(milestones: RecruitingCalendar.upcomingMilestones(
            Self.todayFormatter.string(from: Date()),
            sport: sport,
            division: "D1",
            gender: gender,
            graduationYear: graduationYear
          ))
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
