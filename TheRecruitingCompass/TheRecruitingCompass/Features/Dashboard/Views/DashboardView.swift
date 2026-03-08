import SwiftUI

struct DashboardView: View {
  @State private var viewModel = DashboardViewModel()
  @State private var showParentWizard = false
  @State private var showAddSchool = false
  @Environment(FamilyManager.self) private var familyManager
  @Environment(AuthManager.self) private var authManager

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

        if familyManager.currentMember?.isParent == true && !viewModel.isParentPreviewMode {
          ParentOnboardingBanner(onInviteTapped: {
            showParentWizard = true
          })
            .padding(.horizontal)
            .padding(.top, 8)
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
              EmptyDashboardState(onAddSchool: { showAddSchool = true })
            } else if let stats = viewModel.stats {
              DashboardStatsCardsSection(
                stats: stats,
                visibility: viewModel.widgetVisibility.statsCards
              )
            }

            if let error = viewModel.errorMessage {
              errorSection(error)
            }

            if !viewModel.isEmpty {
              DashboardWidgetsSection(
                visibility: viewModel.widgetVisibility.widgets,
                suggestions: viewModel.suggestions,
                pendingCount: viewModel.suggestionsPendingCount,
                canDismissOrCompleteSuggestions: !viewModel.isParentPreviewMode,
                quickTasks: $viewModel.quickTasks,
                onDismissSuggestion: { id in Task { await viewModel.dismissSuggestion(id) } },
                onCompleteSuggestion: { id in Task { await viewModel.completeSuggestion(id) } },
                onAddTask: viewModel.addTask,
                onToggleTask: viewModel.toggleTaskCompletion,
                onDeleteTask: viewModel.deleteTask,
                onClearCompleted: viewModel.clearCompletedTasks
              )

              DashboardChartsAndDataSection(
                visibility: viewModel.widgetVisibility.widgets,
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
      .sheet(isPresented: $showParentWizard) {
        ParentOnboardingWizardView(
          viewModel: ParentOnboardingWizardViewModel(),
          onDismiss: {
            showParentWizard = false
            Task { await familyManager.loadFamilyData() }
          }
        )
      }
      .sheet(
        isPresented: $showAddSchool,
        onDismiss: { Task { await viewModel.fetchDashboardData() } },
        content: {
          DashboardAddSchoolSheet(
            familyUnitId: familyManager.currentMember?.familyUnitId ?? "",
            userId: authManager.user?.id ?? ""
          )
        }
      )
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
        Text(viewModel.isEmpty ? "Welcome, \(viewModel.userFirstName)!" : "Welcome back, \(viewModel.userFirstName)!")
          .font(.title2)
          .fontWeight(.bold)
          .accessibilityAddTraits(.isHeader)
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
      viewModel.dismissError()
    })
    .accessibilityAddTraits(.updatesFrequently)
  }

  private var logoutButton: some View {
    Button(
      action: { Task { await viewModel.logout() } },
      label: {
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
    )
    .disabled(viewModel.isLoggingOut)
    .opacity(viewModel.isLoggingOut ? 0.6 : 1)
    .padding(.horizontal)
    .accessibilityLabel(viewModel.isLoggingOut ? "Logging out" : "Log out")
    .accessibilityHint("Ends your session and returns to the login screen")
  }

}

// MARK: - Add School Sheet

private struct DashboardAddSchoolSheet: View {
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

#Preview {
  DashboardView()
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
