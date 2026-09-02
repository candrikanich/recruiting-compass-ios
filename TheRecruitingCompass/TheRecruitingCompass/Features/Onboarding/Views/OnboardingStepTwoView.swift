import SwiftUI

/// Step 2 of the v2 onboarding: "Schools to Explore"
/// Shows a horizontal carousel of recommended schools. Users can add or dismiss each card.
/// After the first school add, the push notification priming sheet appears.
struct OnboardingStepTwoView: View {
  @Bindable var viewModel: OnboardingV2ViewModel
  var onFinish: () -> Void

  @Environment(NuxProgressManager.self) private var nuxProgressManager
  @State private var showPushPriming = false
  @State private var hasShownPushPriming = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        headerSection

        if viewModel.isLoadingRecommendations {
          loadingSection
        } else if viewModel.recommendations.isEmpty {
          emptyStateSection
        } else {
          recommendationsCarousel
        }

        if viewModel.schoolsAdded > 0 {
          schoolsAddedBanner
        }

        dashboardButton
      }
      .padding(.vertical, 24)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("Schools to Explore")
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

  // MARK: - Header

  @ViewBuilder private var headerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Based on your sport and location, here are some schools to get you started.")
        .font(.body)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 24)
  }

  // MARK: - Loading

  @ViewBuilder private var loadingSection: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text("Finding schools for you...")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 48)
  }

  // MARK: - Empty State

  @ViewBuilder private var emptyStateSection: some View {
    VStack(spacing: 16) {
      Image(systemName: "building.columns")
        .font(.system(size: 40))
        .foregroundStyle(.tertiary)

      Text("No recommendations yet")
        .font(.headline)

      Text("Continue to your dashboard to start adding schools manually.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 24)
    .padding(.vertical, 32)
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
                let added = await viewModel.addSchool(rec)
                if added && viewModel.schoolsAdded == 1 {
                  nuxProgressManager.completeItem(.firstSchool)
                  if !hasShownPushPriming {
                    hasShownPushPriming = true
                    showPushPriming = true
                  }
                }
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

  @ViewBuilder private var schoolsAddedBanner: some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
      Text("\(viewModel.schoolsAdded) school\(viewModel.schoolsAdded == 1 ? "" : "s") added to your list")
        .font(.subheadline.weight(.medium))
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 24)
  }

  // MARK: - Dashboard Button

  @ViewBuilder private var dashboardButton: some View {
    Button {
      Task {
        if await viewModel.completeOnboarding() {
          onFinish()
        }
      }
    } label: {
      HStack {
        if viewModel.isLoading {
          ProgressView().tint(.white)
        } else {
          Text("Go to Dashboard")
            .font(.body.weight(.semibold))
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 50)
    }
    .buttonStyle(.borderedProminent)
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
        .font(.headline)
        .lineLimit(2)

      // Division + State
      HStack(spacing: 8) {
        if let division = recommendation.division, !division.isEmpty {
          Text(division)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
        }
        if let state = recommendation.state, !state.isEmpty {
          Text(state)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      // Reason chips
      if !recommendation.reasons.isEmpty {
        FlowLayout(spacing: 6) {
          ForEach(recommendation.reasons.prefix(3), id: \.self) { reason in
            Text(reason)
              .font(.caption2)
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
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)

        Button(action: onDismiss) {
          Text("Not a fit")
            .font(.subheadline)
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
