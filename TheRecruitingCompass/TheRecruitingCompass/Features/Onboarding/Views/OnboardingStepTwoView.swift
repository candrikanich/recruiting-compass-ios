import SwiftUI

/// The school step of first-run onboarding (parity with web#1536). Leads with search ("Which school are you
/// most excited about?"); picking a school adds it and stars it. Recommendations sit below, optional, and
/// never block the search. "Not sure yet" skips with no penalty. First-run stops here: no coach is asked for.
/// After the first school add, the push notification priming sheet appears.
struct OnboardingStepTwoView: View {
  @Bindable var viewModel: OnboardingV2ViewModel
  /// False for a parent: setup is finished by their first-run exit, not by this step.
  var completesOnboarding = true
  var onFinish: () -> Void

  @Environment(NuxProgressManager.self) private var nuxProgressManager
  @State private var searchText = ""
  @State private var showPushPriming = false
  @State private var hasShownPushPriming = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        headerSection

        searchSection

        if viewModel.isLoadingRecommendations {
          loadingSection
        } else if !viewModel.recommendations.isEmpty {
          recommendationsSection
        }

        if viewModel.hasAddedSchool {
          schoolsAddedBanner
        }

        finishButton
      }
      .padding(.vertical, 24)
    }
    .scrollContentBackground(.hidden)
    .navigationTitle("Your first school")
    .navigationBarTitleDisplayMode(.large)
    .alert("Error", isPresented: .init(
      get: { viewModel.errorMessage != nil },
      set: { if !$0 { viewModel.clearError() } }
    )) {
      Button("OK") { viewModel.clearError() }
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
    .sheet(isPresented: $showPushPriming) {
      PushNotificationPrimingView(onDismiss: { showPushPriming = false })
        .presentationDetents([.medium])
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("onboardingStepTwo")
    .task { await viewModel.loadRecommendations() }
  }

  /// Progress and the push-priming prompt follow the first school added, from search or a recommendation.
  private func schoolWasAdded() {
    guard viewModel.schoolsAdded == 1 else { return }
    nuxProgressManager.completeItem(.firstSchool)
    if !hasShownPushPriming {
      hasShownPushPriming = true
      showPushPriming = true
    }
  }

  // MARK: - Header

  @ViewBuilder private var headerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let intro = viewModel.schoolStepIntro {
        Text(intro)
          .font(.brand(.body))
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("firstRunIntro")
      }
      Text(viewModel.schoolPrompt)
        .font(.brand(.title3, weight: .semibold))
        .accessibilityAddTraits(.isHeader)
    }
    .padding(.horizontal, 24)
  }

  // MARK: - Search

  @ViewBuilder private var searchSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
        TextField("Search for a school", text: $searchText)
          .textFieldStyle(.plain)
          .autocorrectionDisabled()
          .accessibilityLabel(viewModel.schoolPrompt)
          .accessibilityIdentifier("firstRunSchoolSearch")
          .onChange(of: searchText) { _, text in viewModel.handleSearchQueryChanged(text) }
      }
      .padding(12)
      .background(Color(uiColor: .secondarySystemGroupedBackground))
      .clipShape(RoundedRectangle(cornerRadius: 10))

      if searchText.trimmingCharacters(in: .whitespaces).count >= 3 {
        SchoolAutocompleteDropdown(
          results: viewModel.searchResults,
          isLoading: viewModel.isSearching,
          error: viewModel.searchError,
          onSelect: { college in
            Task {
              if await viewModel.pickSchool(college) {
                searchText = ""
                schoolWasAdded()
              }
            }
          }
        )
        .disabled(viewModel.isPickingSchool)
      }
    }
    .padding(.horizontal, 24)
  }

  // MARK: - Loading

  @ViewBuilder private var loadingSection: some View {
    HStack(spacing: 12) {
      ProgressView()
      Text("Finding schools for you…")
        .font(.brand(.subheadline))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
  }

  // MARK: - Recommendations

  @ViewBuilder private var recommendationsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Or start with a school we picked for you")
        .font(.brand(.subheadline, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
      recommendationsCarousel
    }
  }

  // MARK: - Carousel

  @ViewBuilder private var recommendationsCarousel: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(spacing: 16) {
        ForEach(viewModel.recommendations) { rec in
          RecommendationCardView(
            recommendation: rec,
            onAdd: {
              Task {
                if await viewModel.addSchool(rec) { schoolWasAdded() }
              }
            },
            onDismiss: {
              Task { await viewModel.dismissRecommendation(rec) }
            }
          )
        }
      }
      .padding(.horizontal, 24)
    }
    .scrollClipDisabled()
  }

  // MARK: - Schools Added Banner

  private var addedMessage: String {
    if let name = viewModel.pickedSchoolName, viewModel.schoolsAdded <= 1 {
      return FirstRunCopy.addedConfirmation(schoolName: name)
    }
    let count = viewModel.schoolsAdded
    return "\(count) school\(count == 1 ? "" : "s") added to your list"
  }

  @ViewBuilder private var schoolsAddedBanner: some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
        .accessibilityHidden(true)
      Text(addedMessage)
        .font(.brand(.subheadline, weight: .medium))
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 24)
    .accessibilityElement(children: .combine)
  }

  // MARK: - Finish Button

  private func finish() {
    Task {
      guard completesOnboarding else {
        onFinish()
        return
      }
      if await viewModel.completeOnboarding() { onFinish() }
    }
  }

  @ViewBuilder private var finishLabel: some View {
    HStack {
      if viewModel.isLoading {
        ProgressView().tint(viewModel.hasAddedSchool ? Color.white : Color.accentColor)
      } else {
        Text(viewModel.finishButtonTitle)
          .font(.brand(.body, weight: .semibold))
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 50)
  }

  /// "Not sure yet" is a quiet bordered button; once a school is added the way forward becomes prominent.
  @ViewBuilder private var finishButton: some View {
    Group {
      if viewModel.hasAddedSchool {
        Button(action: finish) { finishLabel }.buttonStyle(.borderedProminent)
      } else {
        Button(action: finish) { finishLabel }.buttonStyle(.bordered)
      }
    }
    .disabled(viewModel.isLoading)
    .padding(.horizontal, 24)
    .accessibilityIdentifier("onboardingGoToDashboardButton")
  }
}

// MARK: - Recommendation Card

private struct RecommendationCardView: View {
  let recommendation: SchoolRecommendation
  let onAdd: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // School name
      Text(recommendation.name)
        .font(.brand(.headline))
        .lineLimit(2)

      // Division + State
      HStack(spacing: 8) {
        if let division = recommendation.division, !division.isEmpty {
          Text(division)
            .font(.brand(.caption, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
        }
        if let state = recommendation.state, !state.isEmpty {
          Text(state)
            .font(.brand(.caption))
            .foregroundStyle(.secondary)
        }
      }

      // Reason chips
      if !recommendation.reasons.isEmpty {
        FlowLayout(spacing: 6) {
          ForEach(recommendation.reasons.prefix(3), id: \.self) { reason in
            Text(reason)
              .font(.brand(.caption2))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color(uiColor: .tertiarySystemFill))
              .clipShape(Capsule())
          }
        }
      }

      Spacer()

      // Action buttons
      HStack(spacing: 12) {
        Button(action: onAdd) {
          Label("Add", systemImage: "plus")
            .font(.brand(.subheadline, weight: .medium))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)

        Button(action: onDismiss) {
          Text("Not a fit")
            .font(.brand(.subheadline))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(16)
    .frame(width: 260)
    .frame(minHeight: 200)
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
  }
}

// Uses Shared/Components/FlowLayout for reason chip wrapping
