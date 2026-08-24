import AppKit

final class SettingsWindow: NSWindow {

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
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
