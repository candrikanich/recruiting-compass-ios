import XCTest
@testable import TheRecruitingCompass

final class LaunchEnvironmentTests: XCTestCase {
  func test_isUnitTestHost_whenXCTestInjectedItsConfiguration() {
    let environment = ["XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration"]
    XCTAssertTrue(LaunchEnvironment.isUnitTestHost(environment: environment))
  }

  func test_isUnitTestHost_whenXCTestInjectedItsBundle_andLeftTheConfigurationPathEmpty() {
    let environment = ["XCTestBundlePath": "PlugIns/TheRecruitingCompassTests.xctest", "XCTestConfigurationFilePath": ""]
    XCTAssertTrue(LaunchEnvironment.isUnitTestHost(environment: environment))
  }

  func test_isNotUnitTestHost_forANormalLaunch() {
    XCTAssertFalse(LaunchEnvironment.isUnitTestHost(environment: [:]))
  }

  func test_isNotUnitTestHost_whenXCTestVariablesAreEmpty() {
    XCTAssertFalse(LaunchEnvironment.isUnitTestHost(environment: ["XCTestConfigurationFilePath": "", "XCTestBundlePath": ""]))
  }

  func test_disablesAnimations_onlyWhenAsked() {
    XCTAssertTrue(LaunchEnvironment.disablesAnimations(arguments: ["myCompass", "--uitesting", "--disable-animations"]))
    XCTAssertFalse(LaunchEnvironment.disablesAnimations(arguments: ["myCompass", "--uitesting"]))
    XCTAssertFalse(LaunchEnvironment.disablesAnimations(arguments: ["myCompass"]))
  }

  func test_runningUnitTests_launchedTheBareHost() {
    XCTAssertTrue(AppEntryPoint.launchedAsUnitTestHost)
  }
}
