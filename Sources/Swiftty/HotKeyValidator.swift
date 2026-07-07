import Carbon.HIToolbox
import HotKey

enum HotKeyValidator {

  enum Result: Equatable {
    case valid
    case invalid(reason: String)
    case systemReserved(reason: String)
  }

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
