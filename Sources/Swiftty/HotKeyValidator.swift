import Carbon.HIToolbox
import HotKey

/// Says whether a shortcut can work as a global hot key, before Swiftty saves it.
///
/// Two things can go wrong: the shortcut is too plain to be safe, or macOS
/// already uses it.
enum HotKeyValidator {

  enum Result: Equatable {
    case valid
    case invalid(reason: String)
    case systemReserved(reason: String)
  }

  /// Function keys are the only keys that are safe on their own, because they type
  /// nothing.
  private static let standaloneKeyCodes: Set<UInt32> = [
    UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
    UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
    UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
    UInt32(kVK_F13), UInt32(kVK_F14), UInt32(kVK_F15), UInt32(kVK_F16),
    UInt32(kVK_F17), UInt32(kVK_F18), UInt32(kVK_F19), UInt32(kVK_F20)
  ]

  static func validate(_ combo: KeyCombo) -> Result {
    guard combo.key != nil else {
      return .invalid(reason: "Choose a key for the shortcut.")
    }

    // Shift does not count here: Shift-A is only a capital A, so it would swallow
    // normal typing.
    let realModifierBits = UInt32(cmdKey | optionKey | controlKey)
    let hasRealModifier = (combo.carbonModifiers & realModifierBits) != 0

    if !hasRealModifier && !standaloneKeyCodes.contains(combo.carbonKeyCode) {
      return .invalid(
        reason: "Use Command, Option, or Control with this key.")
    }

    if conflictsWithSystemShortcut(combo) {
      return .systemReserved(
        reason: "Already used by macOS. Choose another shortcut or change it in "
          + "System Settings > Keyboard > Keyboard Shortcuts."
      )
    }

    return .valid
  }

  // MARK: - System shortcut lookup

  /// The shortcuts macOS keeps for itself, such as Command-Space, and only the ones
  /// that are switched on.
  private static func enabledSystemHotKeys() -> [(keyCode: UInt32, modifiers: UInt32)] {
    var unmanaged: Unmanaged<CFArray>?
    guard CopySymbolicHotKeys(&unmanaged) == noErr,
      let array = unmanaged?.takeRetainedValue() as? [[String: Any]]
    else {
      return []
    }

    var result: [(UInt32, UInt32)] = []
    for entry in array {
      guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true else { continue }
      guard let code = entry[kHISymbolicHotKeyCode as String] as? Int,
        let mods = entry[kHISymbolicHotKeyModifiers as String] as? Int
      else { continue }
      result.append((UInt32(code), UInt32(mods)))
    }
    return result
  }

  /// Shift counts in this comparison, because Command-Shift-4 and Command-4 are
  /// different shortcuts to macOS.
  private static func conflictsWithSystemShortcut(_ combo: KeyCombo) -> Bool {
    let candidateMods = combo.carbonModifiers & UInt32(cmdKey | optionKey | controlKey | shiftKey)

    for sys in enabledSystemHotKeys() {
      let sysMods = sys.modifiers & UInt32(cmdKey | optionKey | controlKey | shiftKey)
      if sys.keyCode == combo.carbonKeyCode && sysMods == candidateMods {
        return true
      }
    }
    return false
  }
}
