import SwiftUI

struct DashboardView: View {
  @State private var viewModel = DashboardViewModel()
  @Environment(FamilyManager.self) private var familyManager

  init(viewModel: DashboardViewModel? = nil) {
    if let viewModel = viewModel {
      _viewModel = State(initialValue: viewModel)
    }
  }

  var body: some View {
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
            } else if let stats = viewModel.stats {
              DashboardStatsCardsSection(stats: stats)
            }

            if let error = viewModel.errorMessage {
              errorSection(error)
            }

            if !viewModel.isEmpty {
              DashboardWidgetsSection(
                suggestions: viewModel.suggestions,
                quickTasks: $viewModel.quickTasks,
                onDismissSuggestion: { id in Task { await viewModel.dismissSuggestion(id) } },
                onCompleteSuggestion: { id in Task { await viewModel.completeSuggestion(id) } },
                onAddTask: viewModel.addTask,
                onToggleTask: viewModel.toggleTaskCompletion,
                onDeleteTask: viewModel.deleteTask,
                onClearCompleted: viewModel.clearCompletedTasks
              )

              DashboardChartsAndDataSection(
                interactionTrends: viewModel.interactionTrends,
                events: viewModel.events,
                metrics: viewModel.metrics,
                schoolsWithOffersPercentage: viewModel.schoolsWithOffersPercentage,
                avgCoachResponsivenessFormatted: viewModel.avgCoachResponsivenessFormatted,
                avgCoachResponsivenessColor: viewModel.avgCoachResponsivenessColor,
                interactionsThisMonth: viewModel.interactionsThisMonth,
                daysUntilGraduationFormatted: viewModel.daysUntilGraduationFormatted,
                isEmpty: viewModel.isEmpty
              )
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

  private func errorSection(_ message: String) -> some View {
    ErrorBanner(message: message, onDismiss: {
      viewModel.errorMessage = nil
    })
    .accessibilityAddTraits(.updatesFrequently)
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
    .environment(AuthManager.shared)
}
