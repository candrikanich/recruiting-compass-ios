import Foundation

struct WhatsNewHighlight: Equatable, Sendable, Identifiable {
  let systemImage: String
  let title: String
  let detail: String

  var id: String { title }
}

struct WhatsNewRelease: Equatable, Sendable, Identifiable {
  let version: AppVersion
  let highlights: [WhatsNewHighlight]

  var id: AppVersion { version }
}

/// User-facing highlights shown once after upgrading to a version. Add an entry when a release has
/// something worth telling users about; versions without an entry upgrade silently.
/// Keep in sync with `fastlane/metadata/en-US/release_notes.txt` (see docs/RELEASE.md).
enum WhatsNewCatalog {
  static let releases: [WhatsNewRelease] = []
}
