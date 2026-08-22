import SwiftUI
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SportGateView")

/// Minimal gate shown to an authenticated player who has finished onboarding but still
/// has a null/blank `primary_sport`. One sport picker + save. On success the caller
/// re-runs `OnboardingManager.loadStatus()` so the gate lifts and the dashboard appears.
@Observable
@MainActor
final class SportGateViewModel {
  nonisolated deinit {}

  var selectedSport: String = ""
  var isSaving = false
  var errorMessage: String?

  /// Canonical registry sports (parity with the position registry) sorted for display.
  let sports: [String] = CanonicalPositions.bySport.keys.sorted()

  private let preferenceService: any PreferenceManaging

  init(preferenceService: (any PreferenceManaging)? = nil) {
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
  }

  var canSave: Bool {
    !selectedSport.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
  }

  /// Saves the picked sport into the player's canonical prefs (fetch-then-merge so
  /// existing player fields survive). Returns true on success.
  func save() async -> Bool {
    let trimmed = selectedSport.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return false }

    isSaving = true
    errorMessage = nil
    defer { isSaving = false }

    do {
      var details: PlayerDetails
      if let existing: PlayerDetails = try await preferenceService.fetchPreferences(category: .player) {
        details = existing
      } else {
        details = .default
      }
      details.primarySport = trimmed
      _ = try await preferenceService.savePreferences(category: .player, data: details)
      logger.debug("Saved primary sport from sport gate")
      return true
    } catch {
      logger.error("Failed to save sport gate selection: \(error.localizedDescription)")
      errorMessage = "Couldn't save your sport. Please try again."
      return false
    }
  }
}

struct SportGateView: View {
  @Environment(AuthManager.self) private var authManager
  @State private var viewModel: SportGateViewModel
  private let onComplete: () -> Void

  init(onComplete: @escaping () -> Void, viewModel: SportGateViewModel? = nil) {
    self.onComplete = onComplete
    _viewModel = State(initialValue: viewModel ?? SportGateViewModel())
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.94, green: 0.96, blue: 1), Color(red: 0.88, green: 0.9, blue: 1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 24) {
        HStack {
          Spacer()
          Button("Sign out") {
            Task { try? await authManager.logout() }
          }
          .font(.footnote)
          .foregroundStyle(.secondary)
        }

        Spacer()

        VStack(spacing: 12) {
          Text("Pick Your Sport")
            .font(.title.weight(.bold))
            .multilineTextAlignment(.center)
          Text("Choose your primary sport so we can tailor your recruiting experience.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Primary Sport *")
            .font(.subheadline.weight(.medium))
          Picker("Sport", selection: $viewModel.selectedSport) {
            Text("Select your sport").tag("")
            ForEach(viewModel.sports, id: \.self) { sport in
              Text(sport).tag(sport)
            }
          }
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
          .background(Color.white.opacity(0.95))
          .clipShape(RoundedRectangle(cornerRadius: 12))

          if let error = viewModel.errorMessage {
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }

        Button {
          Task {
            if await viewModel.save() {
              onComplete()
            }
          }
        } label: {
          if viewModel.isSaving {
            ProgressView().tint(.white)
          } else {
            Text("Continue")
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(viewModel.canSave ? Color.accentColor : Color.gray)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .disabled(!viewModel.canSave)

        Spacer()
      }
      .padding(24)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("sportGateView")
  }
}
