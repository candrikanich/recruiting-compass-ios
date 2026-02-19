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
  @State private var networkMonitor = NetworkMonitor()
  @State private var showResetPassword = false
  @State private var pendingResetPasswordFromDeepLink = false
  @Environment(\.accessibilityReduceMotion) var reduceMotion

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isCheckingSession {
          sessionLoadingView
        } else if authManager.isAuthenticated {
          ZStack(alignment: .top) {
            MainTabView()
            if !networkMonitor.isConnected {
              OfflineBanner()
            }
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
      .onOpenURL { url in
        handleDeepLink(url)
      }
      .onChange(of: authManager.isCheckingSession) { _, isChecking in
        if !isChecking, !authManager.isAuthenticated, pendingResetPasswordFromDeepLink {
          pendingResetPasswordFromDeepLink = false
          showResetPassword = true
        }
      }
      .sheet(isPresented: $showResetPassword, onDismiss: { pendingResetPasswordFromDeepLink = false }) {
        NavigationStack {
          ResetPasswordView(authManager: authManager)
        }
      }
      .environment(authManager)
      .environment(familyManager)
      .environment(networkMonitor)
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
    case .unknown:
      break
    }
  }

  private var sessionLoadingView: some View {
    SessionLoadingView()
  }
}

// MARK: - Session Loading (Splash) View
private struct SessionLoadingView: View {
  @Environment(\.sizeCategory) var sizeCategory

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        LinearGradient.landingBackground
          .ignoresSafeArea()

        VStack(spacing: 16) {
          Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: geometry.size.width * 0.5)
            .scaleEffect(sizeCategory >= .extraLarge ? 1.08 : 1.0)

          ProgressView()
            .tint(.white)
            .scaleEffect(1.2)
        }
      }
    }
  }
}
