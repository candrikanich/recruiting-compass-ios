import XCTest

/// Centralized navigation for the 5-tab `MainTabView`
/// (Dashboard / Schools / Coaches / Interactions / More).
///
/// Tab-bar buttons report `isHittable == false` while a tall scroll view (e.g.
/// the Dashboard) is on screen, so a plain `.tap()` silently no-ops. Every tap
/// here goes through a normalized coordinate and retries until the selection /
/// destination is observed. Overflow features (Offers, Events, Documents, …)
/// live under the More tab as `NavigationLink` rows labeled by their title.
struct MainTabNavigator {
  let app: XCUIApplication

  enum Tab: String {
    case dashboard = "Dashboard"
    case schools = "Schools"
    case coaches = "Coaches"
    case interactions = "Interactions"
    case more = "More"
  }

  /// Selects a top-level tab. Returns whether the tab became selected.
  @discardableResult
  func goTo(_ tab: Tab) -> Bool {
    let button = app.tabBars.buttons[tab.rawValue]
    guard button.waitForExistence(timeout: 5) else { return false }
    for _ in 0..<3 where !button.isSelected {
      tapReliably(button)
      _ = button.waitForExistence(timeout: 1)
    }
    return button.isSelected
  }

  /// Opens the More tab and waits for its "More" navigation bar.
  @discardableResult
  func goToMore() -> Bool {
    let more = app.tabBars.buttons[Tab.more.rawValue]
    guard more.waitForExistence(timeout: 5) else { return false }
    let moreNav = app.navigationBars["More"]
    for _ in 0..<3 where !moreNav.exists {
      tapReliably(more)
      _ = moreNav.waitForExistence(timeout: 5)
    }
    return moreNav.exists
  }

  /// Opens a row in the More menu (e.g. "Offers", "Events", "Documents").
  /// The rows are combined-accessibility `NavigationLink`s, so the label begins
  /// with the section title. Returns once the destination nav bar is present.
  @discardableResult
  func goToMoreSection(_ title: String) -> Bool {
    guard goToMore() else { return false }
    let row = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH %@", title)
    ).firstMatch
    guard row.waitForExistence(timeout: 5) else { return false }
    tapReliably(row)
    return app.navigationBars[title].waitForExistence(timeout: 10)
  }

  /// Taps even when XCUITest reports the element as not hittable.
  private func tapReliably(_ element: XCUIElement) {
    if element.isHittable {
      element.tap()
    } else {
      element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
  }
}
