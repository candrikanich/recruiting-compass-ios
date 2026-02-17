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
  @Environment(\.accessibilityReduceMotion) var reduceMotion
  @ScaledMetric(relativeTo: .largeTitle) private var splashIconSize: CGFloat = 64

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
          .font(.system(size: splashIconSize))
          .foregroundColor(.white)

        ProgressView()
          .tint(.white)
          .scaleEffect(1.2)
      }
    }
  }
}
