import AppKit
import HotKey

@MainActor
final class Preferences {

  static let shared = Preferences()

  static let didChange = Notification.Name("com.parmscript.swiftty.preferences.didChange")

  // MARK: - Keys

  private enum Key {
    static let keyCode = "hotkey.carbonKeyCode"
    static let modifiers = "hotkey.carbonModifiers"
    static let heightFraction = "window.heightFraction"
    static let opacity = "window.opacity"
    static let shellPath = "shell.path"
    static let fontName = "font.name"
    static let fontSize = "font.size"
  }

  // MARK: - Defaults

  static let defaultKeyCombo = KeyCombo(key: .grave, modifiers: [.control, .shift])

  static let defaultHeightFraction: CGFloat = 0.40
  static let minHeightFraction: CGFloat = 0.10
  static let maxHeightFraction: CGFloat = 1.0

  static let defaultOpacity: CGFloat = 0.85
  static let minOpacity: CGFloat = 0.30
  static let maxOpacity: CGFloat = 1.0

  static let defaultFontSize: CGFloat = 14
  static let minFontSize: CGFloat = 8
  static let maxFontSize: CGFloat = 32

  // MARK: - Storage

  private let defaults: UserDefaults

  private init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  // MARK: - Hot-key

  var keyCombo: KeyCombo {
    get {
      guard defaults.object(forKey: Key.keyCode) != nil,
        defaults.object(forKey: Key.modifiers) != nil
      else {
        return Self.defaultKeyCombo
      }
      let code = UInt32(bitPattern: Int32(defaults.integer(forKey: Key.keyCode)))
      let mods = UInt32(bitPattern: Int32(defaults.integer(forKey: Key.modifiers)))
      let combo = KeyCombo(carbonKeyCode: code, carbonModifiers: mods)
      return combo.key == nil ? Self.defaultKeyCombo : combo
    }
    set {
      defaults.set(Int(newValue.carbonKeyCode), forKey: Key.keyCode)
      defaults.set(Int(newValue.carbonModifiers), forKey: Key.modifiers)
      broadcast()
    }
  }

  // MARK: - Height

  var heightFraction: CGFloat {
    get {
      guard defaults.object(forKey: Key.heightFraction) != nil else {
        return Self.defaultHeightFraction
      }
      let raw = CGFloat(defaults.double(forKey: Key.heightFraction))
      return min(max(raw, Self.minHeightFraction), Self.maxHeightFraction)
    }
    set {
      let clamped = min(max(newValue, Self.minHeightFraction), Self.maxHeightFraction)
      defaults.set(Double(clamped), forKey: Key.heightFraction)
      broadcast()
    }
  }

  // MARK: - Opacity

  var opacity: CGFloat {
    get {
      guard defaults.object(forKey: Key.opacity) != nil else {
        return Self.defaultOpacity
      }
      let raw = CGFloat(defaults.double(forKey: Key.opacity))
      return min(max(raw, Self.minOpacity), Self.maxOpacity)
    }
    set {
      let clamped = min(max(newValue, Self.minOpacity), Self.maxOpacity)
      defaults.set(Double(clamped), forKey: Key.opacity)
      broadcast()
    }
  }

  // MARK: - Shell

  var shellPath: String? {
    get { defaults.string(forKey: Key.shellPath) }
    set {
      if let path = newValue, !path.isEmpty {
        defaults.set(path, forKey: Key.shellPath)
      } else {
        defaults.removeObject(forKey: Key.shellPath)
      }
      broadcast()
    }
  }

  var resolvedShellPath: String {
    if let path = shellPath, FileManager.default.isExecutableFile(atPath: path) {
      return path
    }
    return Self.systemLoginShell()
  }

  static func systemLoginShell() -> String {
    if let passwd = getpwuid(getuid()), let cShell = passwd.pointee.pw_shell {
      let shell = String(cString: cShell)
      if FileManager.default.isExecutableFile(atPath: shell) {
        return shell
      }
    }
    if let shell = ProcessInfo.processInfo.environment["SHELL"],
       FileManager.default.isExecutableFile(atPath: shell) {
      return shell
    }
    return "/bin/zsh"
  }

  // MARK: - Font

  var fontName: String? {
    get { defaults.string(forKey: Key.fontName) }
    set {
      if let name = newValue, !name.isEmpty {
        defaults.set(name, forKey: Key.fontName)
      } else {
        defaults.removeObject(forKey: Key.fontName)
      }
      broadcast()
    }
  }

  var fontSize: CGFloat {
    get {
      guard defaults.object(forKey: Key.fontSize) != nil else {
        return Self.defaultFontSize
      }
      let raw = CGFloat(defaults.double(forKey: Key.fontSize))
      return min(max(raw, Self.minFontSize), Self.maxFontSize)
    }
    set {
      let clamped = min(max(newValue, Self.minFontSize), Self.maxFontSize)
      defaults.set(Double(clamped), forKey: Key.fontSize)
      broadcast()
    }
  }

  var terminalFont: NSFont {
    if let name = fontName, let font = NSFont(name: name, size: fontSize) {
      return font
    }
    return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
  }

  // MARK: - Reset

  func restoreDefaults() {
    for key in [
      Key.keyCode, Key.modifiers, Key.heightFraction, Key.opacity,
      Key.shellPath, Key.fontName, Key.fontSize
    ] {
      defaults.removeObject(forKey: key)
    }
    broadcast()
  }

  private func broadcast() {
    NotificationCenter.default.post(name: Self.didChange, object: self)
  }
}
