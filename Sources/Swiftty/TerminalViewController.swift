import AppKit
import SwiftTerm

@MainActor
protocol TerminalEventSink: AnyObject {
  func terminalDidRingBell()
  func terminalDidRequestSettings()
  func terminalDidRequestFontSizeAdjustment(_ delta: CGFloat)
  func terminalDidRequestFontSizeReset()
}

enum TerminalKeyCommand: Equatable {
  case copy
  case paste
  case selectAll
  case clearBuffer
  case resetSession
  case openSettings
  case increaseFontSize
  case decreaseFontSize
  case resetFontSize

  private static let commandShortcuts: [String: TerminalKeyCommand] = [
    "v": .paste,
    "a": .selectAll,
    "k": .clearBuffer,
    ",": .openSettings,
    "+": .increaseFontSize,
    "=": .increaseFontSize,
    "-": .decreaseFontSize,
    "0": .resetFontSize
  ]

  private static let shiftedCommandShortcuts: [String: TerminalKeyCommand] = [
    "r": .resetSession,
    "+": .increaseFontSize,
    "=": .increaseFontSize,
    "_": .decreaseFontSize,
    "-": .decreaseFontSize
  ]

  static func resolve(
    key: String?,
    modifiers: NSEvent.ModifierFlags,
    selectionActive: Bool
  ) -> TerminalKeyCommand? {
    let key = key?.lowercased()
    let modifiers = modifiers.intersection([.command, .option, .control, .shift])

    guard let key else { return nil }

    if modifiers == [.command] {
      if key == "c" { return selectionActive ? .copy : nil }
      return commandShortcuts[key]
    }

    if modifiers == [.command, .shift] {
      return shiftedCommandShortcuts[key]
    }

    return nil
  }
}

final class SwifttyTerminalView: LocalProcessTerminalView {

  var onBell: (() -> Void)?
  var onProcessExit: (() -> Void)?
  var onClearBuffer: (() -> Void)?
  var onResetSession: (() -> Void)?
  var onOpenSettings: (() -> Void)?
  var onAdjustFontSize: ((CGFloat) -> Void)?
  var onResetFontSize: (() -> Void)?

  override func bell(source: Terminal) {
    super.bell(source: source)
    onBell?()
  }

  override func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
    super.processTerminated(source, exitCode: exitCode)
    onProcessExit?()
  }

  // MARK: - Key equivalents

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let command = TerminalKeyCommand.resolve(
      key: event.charactersIgnoringModifiers,
      modifiers: event.modifierFlags,
      selectionActive: selectionActive)
    switch command {
    case .copy: copy(self)
    case .paste: paste(self)
    case .selectAll: selectAll(nil)
    case .clearBuffer: onClearBuffer?()
    case .resetSession: onResetSession?()
    case .openSettings: onOpenSettings?()
    case .increaseFontSize: onAdjustFontSize?(1)
    case .decreaseFontSize: onAdjustFontSize?(-1)
    case .resetFontSize: onResetFontSize?()
    case nil: return super.performKeyEquivalent(with: event)
    }
    return true
  }

  // MARK: - Context menu

  override func menu(for event: NSEvent) -> NSMenu? {
    let menu = NSMenu()
    menu.autoenablesItems = false

    let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
    copyItem.target = self
    copyItem.isEnabled = selectionActive
    menu.addItem(copyItem)

    let pasteItem = NSMenuItem(title: "Paste", action: #selector(paste(_:)), keyEquivalent: "v")
    pasteItem.target = self
    pasteItem.isEnabled = NSPasteboard.general.string(forType: .string) != nil
    menu.addItem(pasteItem)

    let selectAllItem = NSMenuItem(
      title: "Select All", action: #selector(selectAll(_:)),
      keyEquivalent: "a")
    selectAllItem.target = self
    menu.addItem(selectAllItem)

    menu.addItem(.separator())

    let clearItem = NSMenuItem(
      title: "Clear Buffer", action: #selector(menuClearBuffer),
      keyEquivalent: "k")
    clearItem.target = self
    menu.addItem(clearItem)

    let resetItem = NSMenuItem(
      title: "Reset Session", action: #selector(menuResetSession),
      keyEquivalent: "r")
    resetItem.keyEquivalentModifierMask = [.command, .shift]
    resetItem.target = self
    menu.addItem(resetItem)

    menu.addItem(.separator())

    let increaseFontItem = NSMenuItem(
      title: "Increase Font Size", action: #selector(menuIncreaseFontSize),
      keyEquivalent: "+")
    increaseFontItem.target = self
    menu.addItem(increaseFontItem)

    let decreaseFontItem = NSMenuItem(
      title: "Decrease Font Size", action: #selector(menuDecreaseFontSize),
      keyEquivalent: "-")
    decreaseFontItem.target = self
    menu.addItem(decreaseFontItem)

    let resetFontItem = NSMenuItem(
      title: "Reset Font Size", action: #selector(menuResetFontSize),
      keyEquivalent: "0")
    resetFontItem.target = self
    menu.addItem(resetFontItem)

    return menu
  }

  @objc private func menuClearBuffer() { onClearBuffer?() }
  @objc private func menuResetSession() { onResetSession?() }
  @objc private func menuIncreaseFontSize() { onAdjustFontSize?(1) }
  @objc private func menuDecreaseFontSize() { onAdjustFontSize?(-1) }
  @objc private func menuResetFontSize() { onResetFontSize?() }
}

final class TerminalViewController: NSViewController {

  private(set) var terminalView: SwifttyTerminalView!

  weak var eventSink: TerminalEventSink?

  private var isResetting = false
  private var shellStartedAt: Date = .distantPast
  private var fastExitCount = 0

  // MARK: - View construction

  override func loadView() {
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
    container.wantsLayer = true
    container.layer?.backgroundColor = .clear
    self.view = container
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    buildTerminal()
  }

  private func buildTerminal() {
    let term = SwifttyTerminalView(frame: view.bounds)
    term.translatesAutoresizingMaskIntoConstraints = false
    term.wantsLayer = true

    term.onBell = { [weak self] in
      self?.eventSink?.terminalDidRingBell()
    }
    term.onProcessExit = { [weak self] in
      // The process is still marked as running until this callback returns.
      DispatchQueue.main.async {
        guard let self, !self.isResetting else { return }
        self.restartShell()
      }
    }
    term.onClearBuffer = { [weak self] in self?.clearBuffer() }
    term.onResetSession = { [weak self] in self?.resetSession() }
    term.onOpenSettings = { [weak self] in self?.eventSink?.terminalDidRequestSettings() }
    term.onAdjustFontSize = { [weak self] delta in
      self?.eventSink?.terminalDidRequestFontSizeAdjustment(delta)
    }
    term.onResetFontSize = { [weak self] in
      self?.eventSink?.terminalDidRequestFontSizeReset()
    }

    view.addSubview(term)
    NSLayoutConstraint.activate([
      term.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      term.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      term.topAnchor.constraint(equalTo: view.topAnchor),
      term.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    self.terminalView = term
    applyTheme()
  }

  func applyTheme() {
    let theme = TerminalTheme.tokyoNight

    let font = Preferences.shared.terminalFont
    if terminalView.font != font {
      terminalView.font = font
    }

    terminalView.installColors(theme.ansi)
    terminalView.nativeForegroundColor = theme.foreground
    terminalView.nativeBackgroundColor = theme.background
    terminalView.caretColor = theme.cursor
    terminalView.selectedTextBackgroundColor = theme.selection

    terminalView.getTerminal().updateFullScreen()
    terminalView.needsDisplay = true
  }

  // MARK: - Shell lifecycle

  private func restartShell() {
    fastExitCount = Date().timeIntervalSince(shellStartedAt) < 1 ? fastExitCount + 1 : 0
    guard fastExitCount < 3 else {
      terminalView.feed(
        text: "\r\n[swiftty] The shell keeps exiting. Press Command-Shift-R to try again.\r\n")
      return
    }
    startShell()
    focusTerminal()
  }

  /// Call this once the view has its real size, so the shell starts with the right window size.
  func startShell() {
    shellStartedAt = Date()
    let shell = Preferences.shared.resolvedShellPath
    let shellName = (shell as NSString).lastPathComponent

    var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
    let overridden = ["TERM=", "COLORTERM=", "LANG=", "PATH=", "SHELL="]
    env.removeAll { entry in overridden.contains { entry.hasPrefix($0) } }
    env.append("TERM=xterm-256color")
    env.append("COLORTERM=truecolor")
    env.append("LANG=\(currentLang())")
    env.append("PATH=\(robustPath())")
    env.append("SHELL=\(shell)")
    env.append("SWIFTTY=1")

    terminalView.startProcess(
      executable: shell,
      args: [],
      environment: env,
      execName: "-\(shellName)",
      currentDirectory: NSHomeDirectory()
    )
  }

  private func currentLang() -> String {
    if let lang = ProcessInfo.processInfo.environment["LANG"], !lang.isEmpty {
      return lang
    }
    let id = Locale.current.identifier
    return id.isEmpty ? "en_US.UTF-8" : "\(id).UTF-8"
  }

  private func robustPath() -> String {
    let inherited =
      ProcessInfo.processInfo.environment["PATH"]?
      .split(separator: ":").map(String.init) ?? []
    let defaults = [
      "/opt/homebrew/bin", "/opt/homebrew/sbin",
      "/usr/local/bin", "/usr/local/sbin",
      "/usr/bin", "/bin", "/usr/sbin", "/sbin"
    ]
    var seen = Set<String>()
    var ordered: [String] = []
    for entry in defaults + inherited where seen.insert(entry).inserted {
      ordered.append(entry)
    }
    return ordered.joined(separator: ":")
  }

  func focusTerminal() {
    view.window?.makeFirstResponder(terminalView)
  }

  // MARK: - Buffer / session

  func clearBuffer() {
    if terminalView.getTerminal().isCurrentBufferAlternate {
      terminalView.send(txt: "\u{0c}")
      return
    }
    terminalView.feed(text: "\u{1b}[H\u{1b}[2J\u{1b}[3J")
    terminalView.send(txt: "\u{0c}")
  }

  func resetSession() {
    guard !isResetting else { return }
    isResetting = true
    fastExitCount = 0

    terminalView.terminate()
    terminalView.getTerminal().resetToInitialState()
    terminalView.feed(text: "\u{1b}[H\u{1b}[2J\u{1b}[3J")

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.startShell()
      self.focusTerminal()
      self.isResetting = false
    }
  }
}
