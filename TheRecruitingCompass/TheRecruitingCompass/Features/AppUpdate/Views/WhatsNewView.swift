import SwiftUI

struct WhatsNewView: View {
  let release: WhatsNewRelease
  let onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          Text("What's New in \(release.version.description)")
            .font(.brand(.largeTitle, weight: .bold))
            .accessibilityAddTraits(.isHeader)

          ForEach(release.highlights) { highlight in
            HStack(alignment: .top, spacing: 16) {
              Image(systemName: highlight.systemImage)
                .font(.brand(.title2))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 36)
                .accessibilityHidden(true)

              VStack(alignment: .leading, spacing: 4) {
                Text(highlight.title)
                  .font(.brand(.headline))
                Text(highlight.detail)
                  .font(.brand(.subheadline))
                  .foregroundStyle(.secondary)
              }
            }
            .accessibilityElement(children: .combine)
          }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .safeAreaInset(edge: .bottom) {
        Button(action: onDismiss) {
          Text("Continue")
            .font(.brand(.headline))
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.accentPrimary)
        .padding(24)
      }
    }
  }
}

#Preview {
  WhatsNewView(
    release: WhatsNewRelease(
      version: AppVersion(major: 1, minor: 1, patch: 0),
      highlights: [
        WhatsNewHighlight(systemImage: "calendar", title: "Deadlines", detail: "Every date in one place."),
        WhatsNewHighlight(systemImage: "bell.badge", title: "Smarter reminders", detail: "Know what's due next.")
      ]
    ),
    onDismiss: {}
  )
}
