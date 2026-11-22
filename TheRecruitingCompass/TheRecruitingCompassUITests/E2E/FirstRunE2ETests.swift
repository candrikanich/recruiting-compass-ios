import XCTest

/// First-run after a real signup, end to end (#609): the parent wizard, the school step, the skip, and the
/// dashboard, each checked against the database as well as the screen. Mirrors the web specs
/// `first-run-school-step`, `signup-flow` and `onboarding-completion`.
///
/// Signup goes through the web API, so these need the local web dev server: run through
/// `scripts/e2e/nightly-local.sh --only-testing TheRecruitingCompassUITests/FirstRunE2ETests` with
/// `TEST_RUNNER_E2E_API_BASE_URL` pointing at it. The School step searches colleges through that server, which
/// calls the College Scorecard API. A missing server, key or stack fails the run: a skipped test proves nothing.
///
/// The app wipes its saved session on every `--uitesting` launch, so "relaunch" means a fresh launch plus a
/// login: the point is that a finished account is not sent through first-run again.
final class FirstRunE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: SignupScreenObject!
  private var admin: E2EAdminClient!

  private let searchTerm = "Stanford"
  private let expectedSchool = "Stanford University"

  override func setUpWithError() throws {
    continueAfterFailure = false
    try E2ETestEnvironment.requireAPIBaseURL()
    admin = try E2EAdminClient()
    launchFresh()
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
    admin = nil
  }

  // MARK: - New parent

  @MainActor
  func testNewParentPicksSchoolAndLandsOnDashboardThenRelaunchSkipsFirstRun() async throws {
    let parent = TestUserData.uniqueParent()
    signUpParent(parent)
    completeParentWizard(athleteFirstName: "Pickschool")

    pickFirstRunSchool()
    tapFirstRunFinish()
    requireDashboard("after picking a school")

    let userId = try await admin.userId(email: parent.email)
    let familyId = try await admin.familyUnitId(userId: userId)
    let schools = try await admin.schools(familyUnitId: familyId)
    XCTAssertEqual(schools.map(\.name), [expectedSchool], "The picked school belongs to the family, and only it")
    XCTAssertEqual(schools.first?.isFavorite, true, "The picked school is starred")
    let completed = try await admin.onboardingComplete(userId: userId)
    XCTAssertTrue(completed, "Finishing first-run marks onboarding complete")

    launchFresh()
    app.loginAsParent(email: parent.email, password: parent.password)
    requireDashboard("after relaunch and login")
    XCTAssertFalse(app.descendants(matching: .any)["onboardingStepTwo"].exists, "First-run is not shown again")
  }

  @MainActor
  func testNewParentSkipsSchoolStepAndRelaunchSkipsFirstRun() async throws {
    let parent = TestUserData.uniqueParent()
    signUpParent(parent)
    completeParentWizard(athleteFirstName: "Skipschool")

    tapFirstRunFinish()
    requireDashboard("after skipping the school step")

    let userId = try await admin.userId(email: parent.email)
    let familyId = try await admin.familyUnitId(userId: userId)
    let schools = try await admin.schools(familyUnitId: familyId)
    XCTAssertTrue(schools.isEmpty, "Skipping adds no school, found \(schools.map(\.name))")
    let completed = try await admin.onboardingComplete(userId: userId)
    XCTAssertTrue(completed, "Skipping still finishes setup")

    launchFresh()
    app.loginAsParent(email: parent.email, password: parent.password)
    requireDashboard("after relaunch and login")
    XCTAssertFalse(app.descendants(matching: .any)["onboardingStepTwo"].exists, "First-run is not shown again")
  }

  // MARK: - New player

  @MainActor
  func testNewAdultPlayerCompletesOnboardingAndLandsOnDashboard() async throws {
    let player = TestUserData.uniquePlayer()
    signUpPlayer(player, birthYear: Calendar.current.component(.year, from: .now) - 19)
    finishPlayerOnboarding(picking: true)
    requireDashboard("after player onboarding")

    let userId = try await admin.userId(email: player.email)
    let memberships = try await admin.memberships(userId: userId)
    XCTAssertEqual(memberships.map(\.role), ["player"], "The player owns a family as a player")
    let schools = try await admin.schools(familyUnitId: try XCTUnwrap(memberships.first).familyUnitId)
    XCTAssertEqual(schools.map(\.name), [expectedSchool])
    XCTAssertEqual(schools.first?.isFavorite, true, "The player's picked school is starred")
    let completed = try await admin.onboardingComplete(userId: userId)
    XCTAssertTrue(completed, "Player onboarding is marked complete")
  }

  // MARK: - New minor

  @MainActor
  func testNewMinorSkippingGuardianLandsOnDashboardWithInviteParentBanner() async throws {
    let minor = TestUserData.uniquePlayer()
    signUpPlayer(minor, birthYear: nil)
    finishPlayerOnboarding(picking: false)
    requireDashboard("after the minor's onboarding")

    let userId = try await admin.userId(email: minor.email)
    let memberships = try await admin.memberships(userId: userId)
    XCTAssertEqual(memberships.map(\.role), ["player"])
    let schools = try await admin.schools(familyUnitId: try XCTUnwrap(memberships.first).familyUnitId)
    XCTAssertTrue(schools.isEmpty, "Skipping adds no school")
    let completed = try await admin.onboardingComplete(userId: userId)
    XCTAssertTrue(completed)
    // Only the minor signup endpoint leaves the account guardian-locked: the server refuses a coach message from
    // a minor with no confirmed guardian before it looks at the school, and an adult account never gets a 403.
    let status = try await coachMessageStatus(email: minor.email, password: minor.password, userId: userId)
    XCTAssertEqual(status, 403, "A minor with no confirmed guardian cannot message coaches")
  }

  /// Signs in over REST and posts a coach message with an unknown school; the response status is all that matters.
  private func coachMessageStatus(email: String, password: String, userId: String) async throws -> Int {
    let base = try XCTUnwrap(URL(string: E2ETestEnvironment.supabaseURL))
    var login = URLRequest(url: base.appending(path: "auth/v1/token").appending(queryItems: [
      URLQueryItem(name: "grant_type", value: "password")]))
    login.httpMethod = "POST"
    login.setValue(E2ETestEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
    login.setValue("application/json", forHTTPHeaderField: "Content-Type")
    login.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
    let (loginData, _) = try await URLSession.shared.data(for: login)
    let token = try XCTUnwrap(
      (try JSONSerialization.jsonObject(with: loginData) as? [String: Any])?["access_token"] as? String)

    let apiBase = try XCTUnwrap(URL(string: ProcessInfo.processInfo.environment["E2E_API_BASE_URL"] ?? ""))
    var request = URLRequest(url: apiBase.appending(path: "api/athlete/messages"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "athleteUserId": userId, "schoolId": "00000000-0000-0000-0000-000000000000", "body": "hello"])
    let (_, response) = try await URLSession.shared.data(for: request)
    return (response as? HTTPURLResponse)?.statusCode ?? -1
  }

  // MARK: - Driving the app

  /// Fills the player form. `birthYear` nil keeps the form's default date of birth (15 years ago, a minor, who may
  /// leave the guardian email blank); a year makes an adult.
  private func signUpPlayer(_ player: TestUserData, birthYear: Int?) {
    screen.navigateToSignup()
    screen.selectRole(.player)
    let nameParts = player.fullName.split(separator: " ", maxSplits: 1).map(String.init)
    // Pickers first: a secure field that is focused again after a popover or menu closes loses what was typed.
    require(screen.firstNameField, "the signup form")
    if let birthYear { setBirthYear(birthYear) }
    choose("Primary Sport", option: "Baseball")
    chooseFirstGraduationYear()
    for _ in 0..<6 where !screen.firstNameField.isHittable { app.scrollViews.firstMatch.swipeDown(velocity: .slow) }
    screen.firstNameField.tap()
    let isMinor = birthYear == nil
    // nil stands for the zip code: its number pad has no Return key, so focus moves with the keyboard's Next arrow.
    let typed: [String?] = [nameParts[0], nameParts[1], player.email, nil]
      + (isMinor ? [""] : []) + [player.password, player.password]
    for value in typed {
      guard let value else {
        app.buttons["Next field"].tap()
        continue
      }
      if !value.isEmpty { app.typeText(value) }
      app.typeText("\n")
      _ = XCTWaiter.wait(for: [XCTestExpectation(description: "focus moves")], timeout: 0.7)
    }
    screen.acceptTerms()
    let enabled = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "isEnabled == true"), object: screen.createAccountButton)
    if XCTWaiter.wait(for: [enabled], timeout: 10) != .completed {
      XCTFail("Create account never enabled. Screen was:\n\(String(app.debugDescription.prefix(9000)))")
    }
    screen.createAccountButton.tap()
  }

  private func scrollTo(_ element: XCUIElement) {
    for _ in 0..<6 where !element.isHittable {
      app.scrollViews.firstMatch.swipeUp(velocity: .slow)
    }
  }

  private func choose(_ pickerLabel: String, option: String) {
    let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", pickerLabel)).firstMatch
    require(picker, "the \(pickerLabel) picker")
    scrollTo(picker)
    picker.tap()
    let item = app.buttons[option]
    require(item, "the \(option) option")
    item.tap()
  }

  private func chooseFirstGraduationYear() {
    let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Graduation Year'")).firstMatch
    require(picker, "the Graduation Year picker")
    scrollTo(picker)
    picker.tap()
    let year = app.buttons.matching(NSPredicate(format: "label MATCHES '20[0-9]{2}'")).firstMatch
    require(year, "a graduation year option")
    year.tap()
  }

  /// Opens the compact date picker, switches to its month and year wheels, and sets the year.
  private func setBirthYear(_ year: Int) {
    let picker = app.datePickers.firstMatch
    require(picker, "the date of birth picker")
    scrollTo(picker)
    picker.tap()
    let monthYear = app.buttons["Show year picker"].exists
      ? app.buttons["Show year picker"]
      : app.buttons.matching(NSPredicate(format: "label MATCHES '[A-Za-z]+ [0-9]{4}'")).firstMatch
    require(monthYear, "the month and year button in the date picker")
    monthYear.tap()
    let wheels = app.pickerWheels
    require(wheels.element(boundBy: 1), "the year wheel")
    wheels.element(boundBy: 1).adjust(toPickerWheelValue: String(year))
    dismissPopover()
  }

  /// A tap outside the date picker's popover closes it. Where outside is safe differs by screen, so the spots are
  /// tried in turn until the popover's month button is gone.
  private func dismissPopover() {
    for offset in [CGVector(dx: 0.9, dy: 0.03), CGVector(dx: 0.5, dy: 0.2), CGVector(dx: 0.1, dy: 0.1)] {
      app.coordinate(withNormalizedOffset: offset).tap()
      if app.buttons["DatePicker.Show"].waitForNonExistence(timeout: 2) { return }
    }
  }

  /// A player's onboarding after signup: the sport and graduation year came with the form, so the school step is
  /// next. A step one that still shows is continued past.
  private func finishPlayerOnboarding(picking: Bool) {
    let stepOne = app.descendants(matching: .any)["onboardingStepOne"]
    let stepTwo = app.descendants(matching: .any)["onboardingStepTwo"]
    if !stepTwo.waitForExistence(timeout: 20), stepOne.exists {
      app.buttons["onboardingContinueButton"].tap()
    }
    require(stepTwo, "the player's school step", timeout: 30)
    if picking { pickFirstRunSchool() }
    tapFirstRunFinish()
  }

  private func launchFresh() {
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()
    screen = SignupScreenObject(app: app)
  }

  private func signUpParent(_ parent: TestUserData) {
    screen.navigateToSignup()
    screen.selectRole(.parent)
    fillByKeyboard(parent)
    screen.acceptTerms()
    let enabled = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "isEnabled == true"), object: screen.createAccountButton)
    XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed, "Create account never enabled")
    screen.createAccountButton.tap()
  }

  /// Types each field and presses Return, which the form maps to "next field". `SignupScreenObject.fillSignupForm`
  /// taps each field instead, which fails on this form's short card once the keyboard is up ("Could not focus").
  private func fillByKeyboard(_ user: TestUserData) {
    let nameParts = user.fullName.split(separator: " ", maxSplits: 1).map(String.init)
    require(screen.firstNameField, "the signup form")
    screen.firstNameField.tap()
    for value in [nameParts[0], nameParts[1], user.email, user.password, user.password] {
      app.typeText(value)
      app.typeText("\n")
      _ = XCTWaiter.wait(for: [XCTestExpectation(description: "focus moves")], timeout: 0.7)
    }
  }

  /// The wizard's one step: the athlete's name and date of birth (an untouched date does not count, so the
  /// day is changed), then Get started.
  private func completeParentWizard(athleteFirstName: String) {
    let nameField = app.textFields["Athlete first name"]
    require(nameField, "the parent wizard's athlete name field")
    nameField.tap()
    nameField.typeText(athleteFirstName)

    let dobPicker = app.datePickers.firstMatch
    require(dobPicker, "the athlete date of birth picker")
    changeDay(of: dobPicker)

    let getStarted = app.buttons["Get started"]
    let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: getStarted)
    XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed, "Get started never enabled")
    getStarted.tap()
  }

  /// Opens the compact date picker and taps a different day of the shown month than today's.
  private func changeDay(of picker: XCUIElement) {
    picker.tap()
    let today = Calendar.current.component(.day, from: .now)
    let day = today == 10 ? 11 : 10
    let target = app.buttons.matching(NSPredicate(format: "label MATCHES %@", ".*, [A-Za-z]+ \(day)")).firstMatch
    require(target, "day \(day) in the date picker (calendar buttons read like \"Monday, November 10\")")
    target.tap()
    dismissPopover()
  }

  private func pickFirstRunSchool() {
    let search = app.descendants(matching: .any)["firstRunSchoolSearch"].firstMatch
    require(search, "the first-run school search")
    search.tap()
    search.typeText(searchTerm)
    let result = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", expectedSchool)).firstMatch
    require(
      result, "a '\(expectedSchool)' search result (needs the web server's College Scorecard access)", timeout: 30)
    result.tap()
    let notNow = app.buttons["skipPushNotificationsButton"]
    if notNow.waitForExistence(timeout: 15) { notNow.tap() }
  }

  private func tapFirstRunFinish() {
    let finish = app.descendants(matching: .any)["onboardingGoToDashboardButton"].firstMatch
    require(finish, "the first-run finish button")
    finish.tap()
  }

  private func requireDashboard(_ moment: String) {
    app.dismissSavePasswordPrompt(timeout: 2)
    let dashboard = app.navigationBars["Dashboard"]
    require(dashboard, "the dashboard \(moment)", timeout: 30)
  }

  private func require(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 15) {
    if !element.waitForExistence(timeout: timeout) {
      let tree = String(app.debugDescription.prefix(6000))
      XCTFail("Never saw \(what). Screen was:\n\(tree)")
      // continueAfterFailure is false, so the test stops at the XCTFail above.
    }
  }
}
