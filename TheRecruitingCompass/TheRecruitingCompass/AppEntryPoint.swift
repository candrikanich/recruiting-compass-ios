import SwiftUI

/// Unit tests run inside the app process. Launching the real app there boots auth, Supabase, analytics,
/// crash reporting and the flag/entitlement/update stores — network and CPU no test asserts on — so the
/// test host gets an empty scene instead.
@main
enum AppEntryPoint {
  /// Captured at launch: XCTest may scrub its variables from the environment once the bundle loads.
  static let launchedAsUnitTestHost = LaunchEnvironment.isUnitTestHost(environment: ProcessInfo.processInfo.environment)

  static func main() {
    if launchedAsUnitTestHost {
      UnitTestHostApp.main()
    } else {
      TheRecruitingCompassApp.main()
    }
  }
}

private struct UnitTestHostApp: App {
  var body: some Scene {
    WindowGroup { EmptyView() }
  }
}
