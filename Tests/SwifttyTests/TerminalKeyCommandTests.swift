import AppKit
import XCTest
@testable import Swiftty

final class TerminalKeyCommandTests: XCTestCase {

  func testFontSizeShortcuts() {
    XCTAssertEqual(resolve("+", [.command, .shift]), .increaseFontSize)
    XCTAssertEqual(resolve("=", [.command, .shift]), .increaseFontSize)
    XCTAssertEqual(resolve("-", [.command]), .decreaseFontSize)
    XCTAssertEqual(resolve("0", [.command]), .resetFontSize)
  }

  func testUnrelatedModifierFlagsDoNotBlockShortcuts() {
    XCTAssertEqual(resolve("-", [.command, .capsLock]), .decreaseFontSize)
    XCTAssertEqual(resolve("+", [.command, .shift, .numericPad]), .increaseFontSize)
  }

  func testCopyRequiresSelection() {
    XCTAssertNil(resolve("c", [.command], selectionActive: false))
    XCTAssertEqual(resolve("c", [.command], selectionActive: true), .copy)
  }

  func testUnrecognizedShortcutPassesThrough() {
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
