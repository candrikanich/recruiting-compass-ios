import SwiftUI
import Supabase

@main
struct TheRecruitingCompassApp: App {
  @StateObject var authManager = AuthManager.shared

  var body: some Scene {
    WindowGroup {
      if authManager.isAuthenticated {
        TabView {
          Text("Dashboard")
            .environmentObject(authManager)
            .tabItem { Label("Dashboard", systemImage: "house.fill") }
        }
      } else {
        NavigationStack {
          Text("Welcome")
            .environmentObject(authManager)
        }
      }
    }
  }
}
