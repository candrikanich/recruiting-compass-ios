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
  @StateObject var authManager = AuthManager.shared
  @StateObject var familyManager = FamilyManager.shared
  @State private var showResetPassword = false
  @Environment(\.accessibilityReduceMotion) var reduceMotion

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isCheckingSession {
          sessionLoadingView
        } else if authManager.isAuthenticated {
          DashboardView()
            .environmentObject(authManager)
            .environmentObject(familyManager)
        } else {
          NavigationStack {
            LandingView()
              .environmentObject(authManager)
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
    }
    .environmentObject(authManager)
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
        Image(systemName: "compass.fill")
          .font(.system(size: 64))
          .foregroundColor(.white)

        ProgressView()
          .tint(.white)
          .scaleEffect(1.2)
      }
    }
  }
}
