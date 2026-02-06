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

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isCheckingSession {
          sessionLoadingView
        } else if authManager.isAuthenticated {
          DashboardView(authManager: authManager)
            .environmentObject(authManager)
        } else {
          NavigationStack {
            LandingView()
              .environmentObject(authManager)
          }
        }
      }
      .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
      .animation(.easeInOut(duration: 0.2), value: authManager.isCheckingSession)
    }
    .environmentObject(authManager)
  }

  private var sessionLoadingView: some View {
    ZStack {
      LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.3, green: 0.6, blue: 0.4),
          Color(red: 0.05, green: 0.5, blue: 0.35)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
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
