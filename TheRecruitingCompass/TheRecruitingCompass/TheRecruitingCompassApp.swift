//
//  TheRecruitingCompassApp.swift
//  TheRecruitingCompass
//
//  Created by Chris Andrikanich on 2/5/26.
//

import SwiftUI
import Supabase

struct PendingInvite: Identifiable {
  let id: String
}

@main
struct TheRecruitingCompassApp: App {
  @State private var authManager = AuthManager.shared
  @State private var familyManager = FamilyManager.shared
  @State private var onboardingManager = OnboardingManager()
  @State private var networkMonitor = NetworkMonitor()
  @State private var showResetPassword = false
  @State private var showBiometricLock = false
  @State private var pendingResetPasswordFromDeepLink = false
  @State private var pendingInvite: PendingInvite?
  @Environment(\.accessibilityReduceMotion) var reduceMotion

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
            networkMonitor: networkMonitor
          )
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
      .alert("Enable Face ID?", isPresented: Binding(
        get: { authManager.pendingBiometricEnrollmentOffer },
        set: { authManager.pendingBiometricEnrollmentOffer = $0 }
      )) {
        Button("Enable") {
          try? authManager.enableBiometrics()
          authManager.pendingBiometricEnrollmentOffer = false
        }
        Button("Not Now", role: .cancel) {
          authManager.pendingBiometricEnrollmentOffer = false
        }
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

  var body: some View {
    ZStack(alignment: .top) {
      if onboardingManager.needsOnboarding == true {
        OnboardingWrapperView(onComplete: {
          Task { await familyManager.loadFamilyData() }
        })
      } else if onboardingManager.needsOnboarding == false {
        MainTabView()
        if !networkMonitor.isConnected {
          OfflineBanner()
        }
      } else {
        SessionLoadingView()
      }
    }
    .task(id: authManager.isAuthenticated) {
      if authManager.isAuthenticated {
        await onboardingManager.loadStatus()
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
