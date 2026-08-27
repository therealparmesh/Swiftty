import AppKit

/// The window that holds the settings controls.
///
/// It exists only to catch keys: Escape and Command-W close it, and the font size
/// shortcuts keep working while Settings has the focus.
final class SettingsWindow: NSWindow {

  /// Escape closes the window unless the recorder captures it first.
  override func keyDown(with event: NSEvent) {
    if event.charactersIgnoringModifiers == "\u{1b}" {
      close()
      return
    }
    super.keyDown(with: event)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "w" {
      close()
      return true
    }

    let command = TerminalKeyCommand.resolve(
      key: event.charactersIgnoringModifiers,
      modifiers: event.modifierFlags,
      selectionActive: false)
    switch command {
    case .increaseFontSize:
      Preferences.shared.adjustFontSize(by: 1)
    case .decreaseFontSize:
      Preferences.shared.adjustFontSize(by: -1)
    case .resetFontSize:
      Preferences.shared.resetFontSize()
    default:
      return super.performKeyEquivalent(with: event)
    }
    return true
  }
}
