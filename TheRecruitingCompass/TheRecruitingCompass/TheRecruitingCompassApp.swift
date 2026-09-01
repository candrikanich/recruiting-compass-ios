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
  @State private var showResetPassword = false
  @State private var showBiometricLock = false
  @State private var pendingResetPasswordFromDeepLink = false
  @State private var pendingInvite: PendingInvite?
  @State private var pendingPushDestination: NotificationDestination?
  @Environment(\.accessibilityReduceMotion) var reduceMotion

  init() {
    Analytics.setup()
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isCheckingSession {
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
            pendingPushDestination = notification.userInfo?["destination"] as? NotificationDestination
          }
        } else {
          NavigationStack {
            LandingView()
          }
        }
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
        if showBiometricLock {
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
      .sheet(item: $pendingInvite) { pending in
        InviteJoinView(viewModel: InviteJoinViewModel(token: pending.id))
      }
      .environment(authManager)
      .environment(familyManager)
      .environment(networkMonitor)
      .environment(onboardingManager)
      .environment(nuxProgressManager)
    }
  }

  private func handleDeepLink(_ url: URL) {
    let route = DeepLinkHandler.parse(url)
    switch route {
    case .resetPassword:
      pendingResetPasswordFromDeepLink = true
      if !authManager.isCheckingSession, !authManager.isAuthenticated {
        showResetPassword = true
      }
    case .joinInvite(let token):
      pendingInvite = PendingInvite(id: token)
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

  var body: some View {
    ZStack(alignment: .top) {
      // Precedence: full onboarding > sport-only gate > dashboard.
      if onboardingManager.needsOnboarding == true {
        OnboardingWrapperView(onComplete: {
          Task { await familyManager.loadFamilyData() }
        })
      } else if onboardingManager.needsOnboarding == false {
        if onboardingManager.needsSportOnly {
          SportGateView(onComplete: {
            Task { await onboardingManager.loadStatus() }
          })
        } else {
          AdaptiveRootView(pendingPushDestination: $pendingPushDestination)
          if !networkMonitor.isConnected {
            OfflineBanner()
          }
        }
      } else {
        SessionLoadingView()
      }
    }
    .task(id: authManager.isAuthenticated) {
      if authManager.isAuthenticated {
        await onboardingManager.loadStatus()
        if let userId = authManager.user?.id {
          await nuxProgressManager.load(userId: userId)
        }
      }
    }
  }
}

// MARK: - Session Loading (Splash) View

private struct SessionLoadingView: View {
  @Environment(\.sizeCategory) var sizeCategory

  var body: some View {
    ZStack {
      LinearGradient.landingBackground
        .ignoresSafeArea()

      VStack(spacing: 16) {
        Image("AppLogo")
          .resizable()
          .scaledToFit()
          .containerRelativeFrame(.horizontal) { size, _ in size * 0.5 }
          .scaleEffect(sizeCategory >= .extraLarge ? 1.08 : 1.0)

        ProgressView()
          .tint(.white)
          .scaleEffect(1.2)
      }
    }
  }
}
