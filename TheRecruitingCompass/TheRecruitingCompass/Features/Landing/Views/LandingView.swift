import SwiftUI

struct LandingView: View {
  @EnvironmentObject var authManager: AuthManager

  var body: some View {
    ZStack {
      // Background: Emerald gradient
      LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.3, green: 0.6, blue: 0.4),  // emerald-500
          Color(red: 0.05, green: 0.5, blue: 0.35) // emerald-700
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      // Main content
      ScrollView {
        VStack(spacing: 32) {
          Spacer()
            .frame(height: 20)

          // Logo
          VStack {
            Image(systemName: "compass.fill")
              .font(.system(size: 80))
              .foregroundColor(.white)
              .shadow(radius: 10)
              .accessibilityHidden(true)

            Text("Recruiting Compass")
              .font(.title)
              .fontWeight(.bold)
              .foregroundColor(.white)
          }
          .padding(.bottom, 12)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Recruiting Compass")

          // CTA Buttons
          VStack(spacing: 12) {
            NavigationLink(destination: LoginView()) {
              Text("Sign In")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(radius: 5)
            }
            .accessibilityLabel("Sign in to your account")
            .accessibilityHint("Enter your email and password")

            NavigationLink(destination: SignupView()) {
              Text("Create Account")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.white)
                .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.1))
                .cornerRadius(12)
                .shadow(radius: 5)
            }
            .accessibilityLabel("Create a new account")
            .accessibilityHint("Set up a new account with your information")
          }
          .padding(.horizontal)
          .padding(.bottom, 12)

          // Feature Cards
          VStack(spacing: 16) {
            FeatureCard(
              icon: "shield.checkered",
              title: "Track Schools",
              description: "Organize and manage your target colleges in one place"
            )

            FeatureCard(
              icon: "bubble.right.fill",
              title: "Log Interactions",
              description: "Keep track of every conversation with coaches"
            )

            FeatureCard(
              icon: "chart.bar.fill",
              title: "Monitor Progress",
              description: "Visualize your recruiting journey with insights"
            )
          }
          .padding(.horizontal)

          Spacer()
            .frame(height: 20)
        }
      }
    }
    .navigationBarHidden(true)
  }
}

struct FeatureCard: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 32))
        .foregroundColor(.white)
        .accessibilityHidden(true)

      Text(title)
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(.white)

      Text(description)
        .font(.subheadline)
        .foregroundColor(Color.white.opacity(0.85))
        .lineLimit(3)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(20)
    .background(Color.white.opacity(0.1))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Feature: \(title)")
    .accessibilityValue(description)
  }
}

#Preview {
  NavigationStack {
    LandingView()
      .environmentObject(AuthManager.shared)
  }
}
