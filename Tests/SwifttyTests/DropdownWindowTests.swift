import AppKit
import XCTest
@testable import Swiftty

/// Checks where the dropdown window sits when it is open.
@MainActor
final class DropdownWindowTests: XCTestCase {

  // A pretend screen: 1440 x 900, with a 20 pt menu bar on top and an 80 pt Dock
  // at the bottom, so the free part is 800 pt tall.
  private let fullFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
  private let visibleFrame = NSRect(x: 0, y: 80, width: 1_440, height: 800)

  func testHalfOpenWindowHangsFromTheMenuBar() {
    let frame = DropdownWindow.deployedFrame(
      fullFrame: fullFrame,
      visibleFrame: visibleFrame,
      heightFraction: 0.40
    )

    XCTAssertEqual(frame, NSRect(x: 0, y: 560, width: 1_440, height: 320))
    XCTAssertEqual(frame.maxY, visibleFrame.maxY)
  }

  func testFullyOpenWindowFillsTheFreePartOfTheScreen() {
    let frame = DropdownWindow.deployedFrame(
      fullFrame: fullFrame,
      visibleFrame: visibleFrame,
      heightFraction: 1
    )

    XCTAssertEqual(frame, visibleFrame)
  }
}
