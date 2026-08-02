import SwiftUI

struct LandingView: View {
  @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 80
  @State private var showLogin = false
  @State private var showSignup = false

  var body: some View {
    ZStack {
      LinearGradient.landingBackground
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 32) {
          Spacer()
            .frame(height: 20)

          logoSection
          ctaButtons
          featureCardsSection

          Spacer()
            .frame(height: 20)
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }

  // MARK: - Sub-views

  @ViewBuilder
  private var logoSection: some View {
    VStack {
      Image("AppLogo")
        .resizable()
        .scaledToFit()
        .frame(width: logoSize, height: logoSize)
        .shadow(radius: 10)
        .accessibilityHidden(true)

      Text("The Recruiting Compass")
        .font(.title)
        .bold()
        .foregroundStyle(.white)
    }
    .padding(.bottom, 12)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("The Recruiting Compass")
  }

  @ViewBuilder
  private var ctaButtons: some View {
    VStack(spacing: 12) {
      Button(action: { showLogin = true }) {
        Text("Sign In")
          .font(.headline.weight(.semibold))
          .lineLimit(2)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .padding(.horizontal, 16)
          .frame(minHeight: 48)
          .background(LinearGradient.primaryButton)
          .foregroundStyle(.white)
          .clipShape(.rect(cornerRadius: 12))
          .shadow(radius: 5)
      }
      .accessibilityLabel("Sign in to your account")
      .accessibilityHint("Enter your email and password")
      .navigationDestination(isPresented: $showLogin) {
        LoginView()
      }

      Button(action: { showSignup = true }) {
        Text("Create Account")
          .font(.headline.weight(.semibold))
          .lineLimit(2)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .padding(.horizontal, 16)
          .frame(minHeight: 48)
          .background(Color.white)
          .foregroundStyle(Color.nearBlack)
          .clipShape(.rect(cornerRadius: 12))
          .shadow(radius: 5)
      }
      .accessibilityLabel("Create a new account")
      .accessibilityHint("Set up a new account with your information")
      .navigationDestination(isPresented: $showSignup) {
        SignupView()
      }
    }
    .padding(.horizontal)
    .padding(.bottom, 12)
  }

  @ViewBuilder
  private var featureCardsSection: some View {
    VStack(spacing: 16) {
      ForEach(FeatureCardData.landingFeatures) { feature in
        FeatureCard(
          icon: feature.icon,
          title: feature.title,
          description: feature.description
        )
      }
    }
    .padding(.horizontal)
  }
}

#Preview {
  NavigationStack {
    LandingView()
  }
}
