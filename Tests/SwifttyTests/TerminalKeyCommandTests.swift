import AppKit
import XCTest
@testable import Swiftty

/// Checks which key presses Swiftty answers itself, and which ones reach the shell.
final class TerminalKeyCommandTests: XCTestCase {

  func testFontSizeShortcutsAreRecognized() {
    XCTAssertEqual(resolve("+", [.command, .shift]), .increaseFontSize)
    XCTAssertEqual(resolve("=", [.command, .shift]), .increaseFontSize)
    XCTAssertEqual(resolve("-", [.command]), .decreaseFontSize)
    XCTAssertEqual(resolve("0", [.command]), .resetFontSize)
  }

  func testKeysLikeCapsLockDoNotSpoilAShortcut() {
    XCTAssertEqual(resolve("-", [.command, .capsLock]), .decreaseFontSize)
    XCTAssertEqual(resolve("+", [.command, .shift, .numericPad]), .increaseFontSize)
  }

  func testCopyOnlyWorksWhenTextIsSelected() {
    XCTAssertNil(resolve("c", [.command], selectionActive: false))
    XCTAssertEqual(resolve("c", [.command], selectionActive: true), .copy)
  }

  func testUnknownShortcutsAreLeftForTheShell() {
    XCTAssertNil(resolve("x", [.command]))
    XCTAssertNil(resolve("+", [.option]))
  }

  private func resolve(
    _ key: String,
    _ modifiers: NSEvent.ModifierFlags,
    selectionActive: Bool = false
  ) -> TerminalKeyCommand? {
    TerminalKeyCommand.resolve(
      key: key,
      modifiers: modifiers,
      selectionActive: selectionActive)
  }
}
