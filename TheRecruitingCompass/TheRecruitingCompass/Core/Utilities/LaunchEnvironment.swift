import Foundation

/// Launch-time switches that let test runs skip work only a real user session needs.
/// Debug-only: a Release binary always launches as the real app.
enum LaunchEnvironment {
  /// XCTest sets these only in the host app it injects a unit-test bundle into (never in a UI-tested app),
  /// so either one means nobody will drive the UI. Recent Xcode passes `XCTestBundlePath` and leaves
  /// `XCTestConfigurationFilePath` empty; older Xcode sets the configuration path.
  static func isUnitTestHost(environment: [String: String]) -> Bool {
    #if DEBUG
    ["XCTestBundlePath", "XCTestConfigurationFilePath"].contains { !(environment[$0] ?? "").isEmpty }
    #else
    false
    #endif
  }

  /// Opt-in rather than implied by `--uitesting`: marketing clips and App Store screenshots
  /// launch the same way and need real animations.
  static func disablesAnimations(arguments: [String]) -> Bool {
    #if DEBUG
    arguments.contains("--disable-animations")
    #else
    false
    #endif
  }
}
