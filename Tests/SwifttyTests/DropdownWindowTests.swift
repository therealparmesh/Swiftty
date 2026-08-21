import AppKit
import XCTest
@testable import Swiftty

@MainActor
final class DropdownWindowTests: XCTestCase {

  private let fullFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
  private let visibleFrame = NSRect(x: 0, y: 80, width: 1_440, height: 800)

  func testDefaultHeightStartsBelowMenuBar() {
    let frame = DropdownWindow.deployedFrame(
      fullFrame: fullFrame,
      visibleFrame: visibleFrame,
      heightFraction: 0.40
    )

    XCTAssertEqual(frame, NSRect(x: 0, y: 560, width: 1_440, height: 320))
    XCTAssertEqual(frame.maxY, visibleFrame.maxY)
  }

  func testFullHeightFillsVisibleScreen() {
    let frame = DropdownWindow.deployedFrame(
      fullFrame: fullFrame,
      visibleFrame: visibleFrame,
      heightFraction: 1
    )

    XCTAssertEqual(frame, visibleFrame)
  }
}
