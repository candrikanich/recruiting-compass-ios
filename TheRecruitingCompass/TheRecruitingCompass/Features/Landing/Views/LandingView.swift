import SwiftUI

struct LandingView: View {
  @Environment(\.sizeCategory) var sizeCategory

  private var logoSize: CGFloat {
    sizeCategory >= .extraLarge ? 88 : 80
  }

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

  private var logoSection: some View {
    VStack {
      Image(systemName: "location.fill")
        .font(.system(size: logoSize))
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
  }

  private var ctaButtons: some View {
    VStack(spacing: 12) {
      NavigationLink(destination: LoginView()) {
        Text("Sign In")
          .font(.headline)
          .fontWeight(.semibold)
          .lineLimit(2)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .padding(.horizontal, 16)
          .frame(minHeight: 48)
          .background(LinearGradient.primaryButton)
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
          .lineLimit(2)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .padding(.horizontal, 16)
          .frame(minHeight: 48)
          .background(Color.white)
          .foregroundColor(Color.nearBlack)
          .cornerRadius(12)
          .shadow(radius: 5)
      }
      .accessibilityLabel("Create a new account")
      .accessibilityHint("Set up a new account with your information")
    }
    .padding(.horizontal)
    .padding(.bottom, 12)
  }

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
