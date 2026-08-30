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
        VStack(spacing: 28) {
          Spacer()
            .frame(height: 20)

          heroSection
          statsBadge
          featureCardsSection
          tagline

          Spacer()
            .frame(height: 20)
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }

  // MARK: - Hero

  @ViewBuilder
  private var heroSection: some View {
    VStack(spacing: 14) {
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

      Text("Your College Recruiting Command Center")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)

      Text("""
        Navigate college recruiting from finding schools to signing day. \
        For 19 sports. No recruiting service required.
        """)
        .font(.subheadline)
        .foregroundStyle(Color.white.opacity(0.9))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      ctaButtons
    }
    .padding(.horizontal)
    .accessibilityElement(children: .contain)
  }

  // MARK: - Stats Badge

  @ViewBuilder
  private var statsBadge: some View {
    HStack(spacing: 0) {
      statItem("19", label: String(localized: "Sports"))
      statDivider
      statItem("33+", label: String(localized: "Templates"))
      statDivider
      statItem("22", label: String(localized: "NCAA Calendars"))
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(Color.white.opacity(0.12))
    .clipShape(.rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
    }
    .padding(.horizontal)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      String(localized: "19 sports, 33 plus templates, 22 NCAA calendars")
    )
  }

  private func statItem(_ value: String, label: String) -> some View {
    VStack(spacing: 2) {
      Text(value)
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)
      Text(label)
        .font(.caption2.weight(.medium))
        .foregroundStyle(Color.white.opacity(0.75))
    }
    .frame(maxWidth: .infinity)
  }

  private var statDivider: some View {
    Rectangle()
      .fill(Color.white.opacity(0.25))
      .frame(width: 1, height: 28)
  }

  // MARK: - Feature Cards

  @ViewBuilder
  private var featureCardsSection: some View {
    VStack(spacing: 14) {
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

  // MARK: - Tagline

  @ViewBuilder
  private var tagline: some View {
    Text("Free for student athletes and families.")
      .font(.footnote.weight(.medium))
      .foregroundStyle(Color.white.opacity(0.7))
  }

  // MARK: - CTA Buttons

  @ViewBuilder
  private var ctaButtons: some View {
    VStack(spacing: 12) {
      Button(action: { showSignup = true }) {
        Text("Get Started Free")
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
      .accessibilityLabel(String(localized: "Get started free — create a new account"))
      .accessibilityHint(
        String(localized: "Set up a new account with your information")
      )
      .navigationDestination(isPresented: $showSignup) {
        SignupView()
      }

      Button(action: { showLogin = true }) {
        Text("Sign In")
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
      .accessibilityLabel(String(localized: "Sign in to your account"))
      .accessibilityHint(String(localized: "Enter your email and password"))
      .navigationDestination(isPresented: $showLogin) {
        LoginView()
      }
    }
    .padding(.top, 8)
  }
}

#Preview {
  NavigationStack {
    LandingView()
  }
}
