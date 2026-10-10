import SwiftUI

/// Full-screen block shown when this version is below the server's minimum supported version.
struct UpdateRequiredView: View {
  let requiredVersion: AppVersion
  @Environment(\.openURL) private var openURL

  var body: some View {
    ZStack {
      Color.Brand.forest600
        .ignoresSafeArea()

      VStack(spacing: 24) {
        Image(systemName: "arrow.down.app.fill")
          .font(.largeTitle)
          .imageScale(.large)
          .foregroundStyle(.white)
          .accessibilityHidden(true)

        VStack(spacing: 12) {
          Text("Update Required")
            .font(.title.bold())
            .foregroundStyle(.white)
            .accessibilityAddTraits(.isHeader)

          Text(
            // swiftlint:disable:next line_length
            "This version of The Recruiting Compass is no longer supported. Update to version \(requiredVersion.description) or later to keep using the app — your data is safe and will be waiting for you."
          )
          .font(.body)
          .foregroundStyle(.white.opacity(0.9))
          .multilineTextAlignment(.center)
        }

        Button {
          openURL(AppInfo.appStoreURL)
        } label: {
          Text("Update Now")
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.primaryGreen)
        .accessibilityHint("Opens the App Store")

        Text("You're on version \(AppInfo.displayVersion)")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.7))
      }
      .padding(32)
      .frame(maxWidth: 480)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("updateRequiredView")
  }
}

#Preview {
  UpdateRequiredView(requiredVersion: AppVersion(major: 1, minor: 1, patch: 0))
}
