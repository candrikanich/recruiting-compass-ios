//
//  TheRecruitingCompassApp.swift
//  TheRecruitingCompass
//
//  Created by Chris Andrikanich on 2/5/26.
//

import SwiftUI
import Supabase

@main
struct TheRecruitingCompassApp: App {
  @State private var authManager = AuthManager.shared
  @State private var familyManager = FamilyManager.shared
  @State private var showResetPassword = false
  @State private var showBiometricLock = false
  @Environment(\.accessibilityReduceMotion) var reduceMotion

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isCheckingSession {
          sessionLoadingView
        } else if authManager.isAuthenticated {
          MainTabView()
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
              Task { try? await authManager.logout() }
            }
          )
          .transition(.opacity)
        }
      }
      .task {
        if authManager.biometricEnabled {
          showBiometricLock = true
        }
      }
      .onOpenURL { url in
        handleDeepLink(url)
      }
      .sheet(isPresented: $showResetPassword) {
        NavigationStack {
          ResetPasswordView(authManager: authManager)
        }
      }
      .environment(authManager)
      .environment(familyManager)
    }
  }

  private func handleDeepLink(_ url: URL) {
    let route = DeepLinkHandler.parse(url)
    switch route {
    case .resetPassword:
      showResetPassword = true
    case .unknown:
      break
    }
  }

  private var sessionLoadingView: some View {
    ZStack {
      LinearGradient.landingBackground
      .ignoresSafeArea()

      VStack(spacing: 16) {
        Image(systemName: "location.fill")
          .font(.system(size: 64))
          .foregroundColor(.white)

        ProgressView()
          .tint(.white)
          .scaleEffect(1.2)
      }
    }
  }
}
