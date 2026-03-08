import SwiftUI

struct AppErrorView: View {
    let error: AppError
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    private var config: AppErrorConfig { error.config }

    var body: some View {
        ZStack {
            LinearGradient.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                logo

                card

                supportLink
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: config.headline)
        }
    }

    // MARK: - Sub-views

    private var logo: some View {
        Image("LogoStacked")
            .resizable()
            .scaledToFit()
            .frame(height: 120)
            .shadow(radius: 8)
            .accessibilityHidden(true)
    }

    private var card: some View {
        VStack(spacing: 20) {
            iconCircle

            Text(config.headline)
                .font(.title2.bold())
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(config.body)
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)

            if let code = config.statusCode {
                Text("Error \(code)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }

            primaryButton

            if let secondaryLabel = config.secondaryButtonLabel, let onSecondary {
                secondaryButton(label: secondaryLabel, action: onSecondary)
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
        .background(Color.white.opacity(0.95))
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(config.iconBackground)
                .frame(width: 56, height: 56)

            Image(systemName: config.iconName)
                .font(.title2)
                .foregroundStyle(config.iconForeground)
        }
        .accessibilityHidden(true)
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            Text(config.primaryButtonLabel)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(LinearGradient.primaryButton)
                .clipShape(.rect(cornerRadius: 8))
        }
        .accessibilityLabel(config.primaryButtonLabel)
    }

    private func secondaryButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(Color.primary)
                .background(Color(uiColor: .systemGray5))
                .clipShape(.rect(cornerRadius: 8))
        }
        .accessibilityLabel(label)
    }

    private var supportLink: some View {
        Link(
            "Need help? Contact support",
            destination: URL(string: "mailto:support@therecruitingcompass.com")!
        )
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.7))
        .accessibilityLabel("Contact support")
        .accessibilityHint("Opens email to support@therecruitingcompass.com")
    }
}

#Preview("404 Not Found") {
    AppErrorView(
        error: .notFound,
        onPrimary: {},
        onSecondary: {}
    )
}

#Preview("500 Server Error") {
    AppErrorView(
        error: .serverError(statusCode: 500),
        onPrimary: {},
        onSecondary: {}
    )
}

#Preview("Network Offline") {
    AppErrorView(
        error: .networkOffline,
        onPrimary: {},
        onSecondary: nil
    )
}

#Preview("401 Unauthorized") {
    AppErrorView(
        error: .unauthorized,
        onPrimary: {},
        onSecondary: {}
    )
}
