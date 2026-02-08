import SwiftUI
import Combine

struct DashboardView: View {
  @StateObject private var viewModel: DashboardViewModel
  @EnvironmentObject var authManager: AuthManager
  @EnvironmentObject var familyManager: FamilyManager

  init(viewModel: DashboardViewModel = DashboardViewModel()) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        if viewModel.isParentPreviewMode {
          ParentPreviewBanner(
            athleteName: viewModel.selectedAthleteName,
            onDismiss: {
              viewModel.exitParentPreview()
            }
          )
        }

        ScrollView {
          VStack(spacing: 24) {
            headerSection

            if familyManager.currentMember?.isParent == true && !viewModel.isParentPreviewMode {
              athleteSelectorSection
            }

            if viewModel.isLoading && viewModel.stats == nil {
              loadingSection
            } else if viewModel.isEmpty {
              EmptyDashboardState()
            } else {
              statsCardsSection
            }

            if let error = viewModel.errorMessage {
              errorSection(error)
            }

            if !viewModel.isEmpty {
              widgetsSection

              chartsAndDataSection
            }

            Spacer()
              .frame(height: 32)

            logoutButton
          }
          .padding()
        }
        .refreshable {
          await viewModel.refresh()
        }
      }
      .navigationTitle("Dashboard")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            Task {
              await viewModel.refresh()
            }
          }) {
            Image(systemName: "arrow.clockwise")
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("Refresh dashboard")
          .accessibilityHint("Fetches the latest dashboard data")
        }
      }
      .navigationDestination(for: DashboardDestination.self) { destination in
        destinationView(for: destination)
      }
      .task {
        await viewModel.fetchDashboardData()
      }
    }
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if viewModel.isParentPreviewMode {
        Text("\(viewModel.selectedAthleteName)'s Dashboard")
          .font(.title2)
          .fontWeight(.bold)
          .accessibilityAddTraits(.isHeader)
      } else {
        Text("Welcome back, \(viewModel.userFirstName)!")
          .font(.title2)
          .fontWeight(.bold)
          .accessibilityAddTraits(.isHeader)
      }

      if let lastUpdated = viewModel.lastUpdated {
        Text("Last updated: \(lastUpdated, style: .relative)")
          .font(.caption)
          .foregroundColor(Color.secondaryText)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var athleteSelectorSection: some View {
    AthleteSelector(
      athletes: familyManager.athletes,
      selectedAthleteId: familyManager.selectedAthleteId,
      onSelect: { athleteId in
        viewModel.selectAthlete(athleteId)
      }
    )
  }

  private var loadingSection: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      ForEach(0..<6, id: \.self) { _ in
        StatCardSkeleton()
      }
    }
  }

  private var statsCardsSection: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      if let stats = viewModel.stats {
        NavigationLink(value: DashboardDestination.coaches) {
          StatCard(
            title: "Coaches",
            count: stats.coachCount,
            subtitle: nil,
            icon: "person.2.fill",
            gradientColors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
            isEnabled: true,
            destination: .coaches
          )
        }
        .accessibilityLabel("View all coaches, \(stats.coachCount) total")
        .accessibilityHint("Opens your coaches list")
        .buttonStyle(PlainButtonStyle())

        NavigationLink(value: DashboardDestination.schools) {
          StatCard(
            title: "Schools",
            count: stats.schoolCount,
            subtitle: nil,
            icon: "building.2.fill",
            gradientColors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
            isEnabled: true,
            destination: .schools
          )
        }
        .accessibilityLabel("View all schools, \(stats.schoolCount) total")
        .accessibilityHint("Opens your schools list")
        .buttonStyle(PlainButtonStyle())

        NavigationLink(value: DashboardDestination.interactions) {
          StatCard(
            title: "Interactions",
            count: stats.interactionCount,
            subtitle: nil,
            icon: "bubble.left.and.bubble.right.fill",
            gradientColors: [Color(hex: "#10B981"), Color(hex: "#059669")],
            isEnabled: true,
            destination: .interactions
          )
        }
        .accessibilityLabel("View all interactions, \(stats.interactionCount) total")
        .accessibilityHint("Opens your interactions list")
        .buttonStyle(PlainButtonStyle())

        NavigationLink(value: DashboardDestination.offers) {
          StatCard(
            title: "Offers",
            count: stats.totalOffers,
            subtitle: nil,
            icon: "gift.fill",
            gradientColors: [Color(hex: "#F97316"), Color(hex: "#EA580C")],
            isEnabled: true,
            destination: .offers
          )
        }
        .accessibilityLabel("View all offers, \(stats.totalOffers) total")
        .accessibilityHint("Opens your offers list")
        .buttonStyle(PlainButtonStyle())

        NavigationLink(value: DashboardDestination.accepted) {
          StatCard(
            title: "Accepted",
            count: stats.acceptedOffers,
            subtitle: stats.acceptanceRateFormatted,
            icon: "checkmark.circle.fill",
            gradientColors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
            isEnabled: true,
            destination: .accepted
          )
        }
        .accessibilityLabel("View accepted offers, \(stats.acceptedOffers) total")
        .accessibilityHint("Opens your accepted offers list")
        .buttonStyle(PlainButtonStyle())

        NavigationLink(value: DashboardDestination.aTier) {
          StatCard(
            title: "A-Tier",
            count: stats.aTierSchoolCount,
            subtitle: nil,
            icon: "star.fill",
            gradientColors: [Color(hex: "#6366F1"), Color(hex: "#4F46E5")],
            isEnabled: true,
            destination: .aTier
          )
        }
        .accessibilityLabel("View A-Tier schools, \(stats.aTierSchoolCount) total")
        .accessibilityHint("Opens your top-tier schools list")
        .buttonStyle(PlainButtonStyle())
      }
    }
  }

  private func errorSection(_ message: String) -> some View {
    ErrorBanner(message: message, onDismiss: {
      viewModel.errorMessage = nil
    })
    .accessibilityAddTraits(.updatesFrequently)
  }

  private var widgetsSection: some View {
    VStack(spacing: 16) {
      ActionItemsWidget(
        suggestions: viewModel.suggestions,
        onDismiss: { id in
          Task {
            await viewModel.dismissSuggestion(id)
          }
        },
        onComplete: { id in
          Task {
            await viewModel.completeSuggestion(id)
          }
        }
      )

      QuickTaskWidget(
        tasks: $viewModel.quickTasks,
        onAddTask: viewModel.addTask,
        onToggleTask: viewModel.toggleTaskCompletion,
        onDeleteTask: viewModel.deleteTask,
        onClearCompleted: viewModel.clearCompletedTasks
      )
    }
  }

  private var chartsAndDataSection: some View {
    VStack(spacing: 16) {
      if !viewModel.interactionTrends.isEmpty {
        InteractionTrendsChart(trends: viewModel.interactionTrends)
      }

      if !viewModel.events.isEmpty {
        UpcomingEventsWidget(events: viewModel.events)
      }

      if !viewModel.activities.isEmpty {
        RecentActivityFeed(activities: viewModel.activities)
      }

      if !viewModel.metrics.isEmpty {
        PerformanceMetricsWidget(metrics: viewModel.metrics)
      }

      if !viewModel.isEmpty {
        AtAGlanceSummary(
          schoolsWithOffers: viewModel.schoolsWithOffersPercentage,
          avgCoachResponsiveness: viewModel.avgCoachResponsivenessFormatted,
          avgResponsivenessColor: viewModel.avgCoachResponsivenessColor,
          interactionsThisMonth: viewModel.interactionsThisMonth,
          daysUntilGraduation: viewModel.daysUntilGraduationFormatted
        )
      }
    }
  }

  private var logoutButton: some View {
    Button(action: {
      Task {
        await viewModel.logout()
      }
    }) {
      HStack {
        Image(systemName: "rectangle.portrait.and.arrow.right")
          .accessibilityHidden(true)
        Text(viewModel.isLoggingOut ? "Logging out..." : "Log Out")
          .font(.callout.weight(.semibold))
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .foregroundColor(.white)
      .background(Color.errorRed)
      .cornerRadius(8)
    }
    .disabled(viewModel.isLoggingOut)
    .opacity(viewModel.isLoggingOut ? 0.6 : 1)
    .padding(.horizontal)
    .accessibilityLabel(viewModel.isLoggingOut ? "Logging out" : "Log out")
    .accessibilityHint("Ends your session and returns to the login screen")
  }

  @ViewBuilder
  private func destinationView(for destination: DashboardDestination) -> some View {
    switch destination {
    case .coaches:
      CoachesListView()
    case .schools:
      SchoolsListView()
    case .interactions:
      InteractionsListView()
    case .offers:
      OffersListView()
    case .accepted:
      OffersListView()
    case .aTier:
      SchoolsListView()
    case .suggestions:
      SuggestionsListView(viewModel: viewModel)
    }
  }
}

#Preview {
  DashboardView()
    .environmentObject(AuthManager.shared)
}
