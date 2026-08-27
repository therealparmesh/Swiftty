import Foundation
import XCTest
@testable import Swiftty

/// Checks that settings come back the way they went in.
@MainActor
final class PreferencesTests: XCTestCase {

  func testNewInstallStartsWithTheDefaultValues() {
    let (preferences, cleanup) = makePreferences()
    defer { cleanup() }

    XCTAssertEqual(preferences.heightFraction, 0.40)
    XCTAssertEqual(preferences.opacity, 0.85)
    XCTAssertEqual(preferences.fontSize, 14)
  }

  func testUntidyValuesAreRoundedAndPulledIntoRange() {
    let (preferences, cleanup) = makePreferences()
    defer { cleanup() }

    preferences.heightFraction = 0.426
    preferences.opacity = 2
    preferences.fontSize = 18.6

    XCTAssertEqual(preferences.heightFraction, 0.43)
    XCTAssertEqual(preferences.opacity, Preferences.maxOpacity)
    XCTAssertEqual(preferences.fontSize, 19)
  }

  func testFontSizeStopsAtTheLimitAndGoesBackToTheDefault() {
    let (preferences, cleanup) = makePreferences()
    defer { cleanup() }

    preferences.fontSize = Preferences.maxFontSize
    preferences.adjustFontSize(by: 1)
    XCTAssertEqual(preferences.fontSize, Preferences.maxFontSize)

    preferences.adjustFontSize(by: -1)
    XCTAssertEqual(preferences.fontSize, Preferences.maxFontSize - 1)

    preferences.resetFontSize()
    XCTAssertEqual(preferences.fontSize, Preferences.defaultFontSize)
  }

  /// A throwaway defaults suite per test, so nothing touches the real settings.
  private func makePreferences() -> (Preferences, () -> Void) {
    let suiteName = "PreferencesTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let preferences = Preferences(defaults: defaults)
    return (preferences, { defaults.removePersistentDomain(forName: suiteName) })
  }
}
