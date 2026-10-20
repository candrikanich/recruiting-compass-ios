//
//  TheRecruitingCompassApp.swift
//  TheRecruitingCompass
//
//  Created by Chris Andrikanich on 2/5/26.
//

import SwiftUI
import Supabase
import UIKit
import UserNotifications
import os
import PostHog

@main
struct TheRecruitingCompassApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var authManager = AuthManager.shared
  @State private var familyManager = FamilyManager.shared
  @State private var onboardingManager = OnboardingManager()
  @State private var networkMonitor = NetworkMonitor()
  @State private var nuxProgressManager = NuxProgressManager.shared
  @State private var entitlementStore = EntitlementStore()
  @State private var appUpdateManager = AppUpdateManager()
  @State private var featureFlagStore = FeatureFlagStore()
  @State private var showResetPassword = false
  @State private var showBiometricLock = false
  @State private var pendingResetPasswordFromDeepLink = false
  @State private var pendingInvite: PendingInvite?
  @State private var pendingGuardianClaim: PendingInvite?
  @State private var pendingPushDestination: NotificationDestination?
  @Environment(\.accessibilityReduceMotion) var reduceMotion

  init() {
    CrashReporting.start()
    Analytics.setup()
    BrandFont.configureNavigationBarAppearance()
  }

  var body: some Scene {
    WindowGroup {
      Group {
        // Replaces the whole UI rather than overlaying it, so nothing behind it stays reachable —
        // not by VoiceOver, and not by sheets presented from inside the app.
        if case .updateRequired(let version) = appUpdateManager.status {
          UpdateRequiredView(requiredVersion: version)
            .transition(.opacity)
        } else if authManager.isCheckingSession {
          SessionLoadingView()
        } else if authManager.isAuthenticated {
          AuthenticatedContent(
            authManager: authManager,
            familyManager: familyManager,
            onboardingManager: onboardingManager,
            networkMonitor: networkMonitor,
            pendingPushDestination: $pendingPushDestination
          )
          .task {
            UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
            // Push permission is now requested via PushNotificationPrimingView during
            // onboarding Step 2 (after first school add). For returning users who already
            // granted permission, re-register to keep the device token current.
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
              await PushNotificationManager.shared.requestPermission()
            }
            await PushNotificationManager.shared.syncBadgeCount()
            if let userId = authManager.user?.id {
              try? await PushPreferencesServiceImpl(supabaseManager: .shared).seedDefaultPreferences(userId: userId)
            }
          }
          .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await PushNotificationManager.shared.syncBadgeCount() }
          }
          .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { notification in
            guard let destination = notification.userInfo?["destination"] as? NotificationDestination else {
              pendingPushDestination = nil
              return
            }
            // A cold-launch tap arrives before the first flag refresh; wait for it (fails open on timeout).
            Task {
              await featureFlagStore.waitForInitialState()
              pendingPushDestination = destination.gated(by: featureFlagStore)
            }
          }
        } else {
          NavigationStack {
            LandingView()
          }
        }
      }
      .alert("Update Available", isPresented: updatePromptBinding) {
        Button("Update") {
          appUpdateManager.dismissUpdatePrompt()
          UIApplication.shared.open(AppInfo.appStoreURL)
        }
        Button("Not Now", role: .cancel) {
          appUpdateManager.dismissUpdatePrompt()
        }
      } message: {
        Text("A new version of The Recruiting Compass is available with the latest improvements and fixes.")
      }
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 0.3),
        value: authManager.isAuthenticated
      )
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 0.2),
        value: authManager.isCheckingSession
      )
      .overlay {
        if showBiometricLock && !appUpdateManager.isUpdateRequired {
          BiometricLockView(
            authManager: authManager,
            onSuccess: { showBiometricLock = false },
            onFailure: {
              showBiometricLock = false
              Task {
                do {
                  try await authManager.logout()
                } catch {
                  authManager.errorMessage = error.localizedDescription
                }
              }
            }
          )
          .transition(.opacity)
        }
      }
      .overlay {
        if !authManager.isAuthenticated {
          TurnstileChallengeOverlay()
        }
      }
      .task {
        async let flags: Void = featureFlagStore.refresh()
        await appUpdateManager.check()
        await flags
      }
      .onChange(of: appUpdateManager.isUpdateRequired) { _, isRequired in
        guard isRequired else { return }
        // App-level sheets are presented above the Group, so close them explicitly.
        showResetPassword = false
        pendingInvite = nil
        pendingGuardianClaim = nil
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
        Task { await appUpdateManager.checkIfStale() }
        Task { await featureFlagStore.refresh() }
      }
      .task {
        if authManager.isAuthenticated && authManager.biometricEnabled {
          showBiometricLock = true
        }
      }
      .alert("Enable Face ID?", isPresented: $authManager.pendingBiometricEnrollmentOffer) {
        Button("Enable") {
          do {
            try authManager.enableBiometrics()
          } catch {
            // Keychain write failed — biometrics silently not enabled.
            // User sees the alert dismiss normally.
          }
          authManager.pendingBiometricEnrollmentOffer = false
        }
        Button("Not Now", role: .cancel) {
          authManager.pendingBiometricEnrollmentOffer = false
        }
      } message: {
        Text("Sign in quickly and securely with Face ID on future visits.")
      }
      .onOpenURL { url in
        handleDeepLink(url)
      }
      // AuthManager clears the user from several paths (logout, failed session restore,
      // aborted signup), so key off the user id itself rather than any one of them.
      .onChange(of: authManager.user?.id) { previousUserId, _ in
        guard previousUserId != nil else { return }
        resetUserScopedState()
      }
      .onChange(of: authManager.isCheckingSession) { _, isChecking in
        if !isChecking, !authManager.isAuthenticated, pendingResetPasswordFromDeepLink {
          pendingResetPasswordFromDeepLink = false
          showResetPassword = true
        }
      }
      .sheet(
        isPresented: $showResetPassword,
        onDismiss: { pendingResetPasswordFromDeepLink = false },
        content: {
          NavigationStack {
            ResetPasswordView(authManager: authManager)
          }
        }
      )
      .sheet(
        item: $pendingInvite,
        onDismiss: { Task { await familyManager.loadFamilyData() } },
        content: { pending in InviteJoinView(viewModel: InviteJoinViewModel(token: pending.id)) }
      )
      .sheet(
        item: $pendingGuardianClaim,
        onDismiss: { Task { await familyManager.loadFamilyData() } },
        content: { pending in GuardianClaimView(viewModel: GuardianClaimViewModel(token: pending.id)) }
      )
      .environment(authManager)
      .environment(familyManager)
      .environment(networkMonitor)
      .environment(onboardingManager)
      .environment(nuxProgressManager)
      .environment(entitlementStore)
      .environment(appUpdateManager)
      .environment(featureFlagStore)
    }
  }

  private var updatePromptBinding: Binding<Bool> {
    Binding(
      get: { appUpdateManager.isShowingUpdatePrompt },
      set: { isShowing in
        if !isShowing { appUpdateManager.dismissUpdatePrompt() }
      }
    )
  }

  /// App-lifetime state that belongs to one user. Mirrors web's `resetAppState()`.
  private func resetUserScopedState() {
    familyManager.reset()
    nuxProgressManager.reset()
    onboardingManager.reset()
    entitlementStore.reset()
    Task { await InMemoryCache.shared.removeAll() }
  }

  private func handleDeepLink(_ url: URL) {
    // A blocked build can't complete invite/reset flows; the link works again after updating.
    guard !appUpdateManager.isUpdateRequired else { return }
    let route = DeepLinkHandler.parse(url)
    switch route {
    case .joinInvite, .guardianClaim:
      // Gated routes wait for the first flag refresh so a cold-launch link can't beat a kill switch.
      Task {
        await featureFlagStore.waitForInitialState()
        guard !appUpdateManager.isUpdateRequired else { return }
        presentRoute(route)
      }
    default:
      presentRoute(route)
    }
  }

  private func presentRoute(_ route: DeepLinkRoute) {
    switch route {
    case .resetPassword:
      pendingResetPasswordFromDeepLink = true
      if !authManager.isCheckingSession, !authManager.isAuthenticated {
        showResetPassword = true
      }
    case .joinInvite(let token):
      guard featureFlagStore.isEnabled(.familyInvites) else { return }
      pendingInvite = PendingInvite(id: token)
    case .guardianClaim(let token):
      guard featureFlagStore.isEnabled(.guardianClaim) else { return }
      pendingGuardianClaim = PendingInvite(id: token)
    case .unknown:
      break
    }
  }
}

// MARK: - Authenticated Content

private struct AuthenticatedContent: View {
  let authManager: AuthManager
  let familyManager: FamilyManager
  let onboardingManager: OnboardingManager
  let networkMonitor: NetworkMonitor
  @Binding var pendingPushDestination: NotificationDestination?
  @Environment(NuxProgressManager.self) private var nuxProgressManager
  @Environment(AppUpdateManager.self) private var appUpdateManager

  var body: some View {
    ZStack(alignment: .top) {
      switch FamilyGate.route(for: familyManager.membership) {
      case .loading:
        SessionLoadingView()
      case .retry:
        FamilyLoadFailedView(retry: { await loadFamilyAndOnboarding() })
      case .setup:
        FamilySetupView(familyManager: familyManager)
      case .passThrough:
        appContent
      }
    }
    // A parent removed from (or a member of a deleted) family reaches the gate on the next foreground.
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
      Task { await familyManager.loadFamilyData() }
    }
    // Keyed by user id, not isAuthenticated: resetUserScopedState() puts onboarding back to
    // "loading", so any change of user must reload it or routing would stall.
    .task(id: authManager.user?.id) {
      if authManager.isAuthenticated {
        await loadFamilyAndOnboarding()
        if let userId = authManager.user?.id {
          await nuxProgressManager.load(userId: userId)
        }
      }
    }
  }

  /// Family first: a parent in a family passes onboarding even if the best-effort completion flag is unset.
  private func loadFamilyAndOnboarding() async {
    await familyManager.loadFamilyData()
    await onboardingManager.loadStatus(isInFamily: familyManager.membership == .member)
  }

  // Precedence: full onboarding > sport-only gate > dashboard.
  @ViewBuilder
  private var appContent: some View {
    if onboardingManager.needsOnboarding == true {
      OnboardingWrapperView(onComplete: {
        Task { await familyManager.loadFamilyData() }
      })
    } else if onboardingManager.needsOnboarding == false {
      if onboardingManager.needsSportOnly {
        SportGateView(onComplete: {
          Task { await onboardingManager.loadStatus(isInFamily: familyManager.membership == .member) }
        })
      } else {
        AdaptiveRootView(pendingPushDestination: $pendingPushDestination)
          .task { appUpdateManager.evaluateWhatsNew() }
          .sheet(item: whatsNewBinding) { release in
            WhatsNewView(release: release, onDismiss: appUpdateManager.dismissWhatsNew)
          }
        if !networkMonitor.isConnected {
          OfflineBanner()
        }
      }
    } else {
      SessionLoadingView()
    }
  }

  private var whatsNewBinding: Binding<WhatsNewRelease?> {
    Binding(
      get: { appUpdateManager.pendingWhatsNew },
      set: { release in
        if release == nil { appUpdateManager.dismissWhatsNew() }
      }
    )
  }
}

// MARK: - Session Loading (Splash) View

private struct SessionLoadingView: View {
  var body: some View {
    ZStack {
      Color.Brand.forest600
        .ignoresSafeArea()

      CompassLoadingAnimation()
    }
  }
}
