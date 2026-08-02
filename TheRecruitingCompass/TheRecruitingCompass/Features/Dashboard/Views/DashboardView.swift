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
            DashboardHeaderSection(
              isParentPreviewMode: viewModel.isParentPreviewMode,
              selectedAthleteName: viewModel.selectedAthleteName,
              isEmpty: viewModel.isEmpty,
              userFirstName: viewModel.userFirstName
            )

            if familyManager.currentMember?.isParent == true && !viewModel.isParentPreviewMode {
              DashboardAthleteSelectorSection(
                athletes: familyManager.athletes,
                selectedAthleteId: familyManager.selectedAthleteId,
                onSelect: { athleteId in viewModel.selectAthlete(athleteId) }
              )
            }

            if viewModel.isLoading && viewModel.stats == nil {
              DashboardLoadingSection()
            } else if viewModel.isEmpty {
              EmptyDashboardState(onAddSchool: { showAddSchool = true })
            } else if let stats = viewModel.stats {
              DashboardStatsCardsSection(
                stats: stats,
                visibility: viewModel.widgetVisibility.statsCards
              )
            }

            if let error = viewModel.errorMessage {
              DashboardErrorSection(message: error, onDismiss: { viewModel.dismissError() })
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
                interactionsThisMonth: viewModel.interactionsThisMonth,
                daysUntilGraduationFormatted: viewModel.daysUntilGraduationFormatted,
                isEmpty: viewModel.isEmpty
              )
            }

            Spacer()
              .frame(height: 32)

            DashboardLogoutButton(
              isLoggingOut: viewModel.isLoggingOut,
              onLogout: { await viewModel.logout() }
            )
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

}

// MARK: - Dashboard Sub-views

private struct DashboardHeaderSection: View {
  let isParentPreviewMode: Bool
  let selectedAthleteName: String
  let isEmpty: Bool
  let userFirstName: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if isParentPreviewMode {
        Text("\(selectedAthleteName)'s Dashboard")
          .font(.title2)
          .bold()
          .accessibilityAddTraits(.isHeader)
      } else {
        Text(isEmpty ? "Welcome, \(userFirstName)!" : "Welcome back, \(userFirstName)!")
          .font(.title2)
          .bold()
          .accessibilityAddTraits(.isHeader)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct DashboardAthleteSelectorSection: View {
  let athletes: [FamilyMember]
  let selectedAthleteId: String?
  let onSelect: (String) -> Void

  var body: some View {
    AthleteSelector(
      athletes: athletes,
      selectedAthleteId: selectedAthleteId,
      onSelect: onSelect
    )
  }
}

private struct DashboardLoadingSection: View {
  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      ForEach(0..<6, id: \.self) { _ in
        StatCard(
          title: "Loading",
          count: 0,
          subtitle: nil,
          description: nil,
          icon: "circle",
          gradientColors: [Color.Brand.slate100, Color.Brand.slate100],
          isEnabled: false,
          destination: nil
        )
        .redacted(reason: .placeholder)
      }
    }
  }
}

private struct DashboardErrorSection: View {
  let message: String
  let onDismiss: () -> Void

  var body: some View {
    ErrorBanner(message: message, onDismiss: onDismiss)
      .accessibilityAddTraits(.updatesFrequently)
  }
}

private struct DashboardLogoutButton: View {
  let isLoggingOut: Bool
  let onLogout: () async -> Void

  var body: some View {
    Button(
      action: { Task { await onLogout() } },
      label: {
        HStack {
          Image(systemName: "rectangle.portrait.and.arrow.right")
            .accessibilityHidden(true)
          Text(isLoggingOut ? "Logging out..." : "Log Out")
            .font(.callout.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
        .foregroundStyle(.white)
        .background(Color.errorRed)
        .clipShape(.rect(cornerRadius: 8))
      }
    )
    .disabled(isLoggingOut)
    .opacity(isLoggingOut ? 0.6 : 1)
    .padding(.horizontal)
    .accessibilityLabel(isLoggingOut ? "Logging out" : "Log out")
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
