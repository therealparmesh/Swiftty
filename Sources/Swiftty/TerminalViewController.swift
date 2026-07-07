import AppKit
import SwiftTerm

@MainActor
protocol TerminalEventSink: AnyObject {
  func terminalDidRingBell()
  func terminalDidRequestSettings()
}

final class SwifttyTerminalView: LocalProcessTerminalView {

  var onBell: (() -> Void)?
  var onProcessExit: (() -> Void)?
  var onClearBuffer: (() -> Void)?
  var onResetSession: (() -> Void)?
  var onOpenSettings: (() -> Void)?

  override func bell(source: Terminal) {
    super.bell(source: source)
    onBell?()
  }

  override func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
    super.processTerminated(source, exitCode: exitCode)
    onProcessExit?()
  }

  // MARK: - Copy / paste

  @objc override func copy(_ sender: Any?) {
    guard let selected = getSelection() else { return }
    guard !selected.isEmpty else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(selected, forType: .string)
  }

  @objc override func paste(_ sender: Any?) {
    guard let raw = NSPasteboard.general.string(forType: .string) else { return }
    guard !raw.isEmpty else { return }
    send(txt: raw)
  }

  // MARK: - Key equivalents

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let key = event.charactersIgnoringModifiers?.lowercased()

    if mods == [.command] {
      switch key {
      case "c" where selectionActive:
        copy(nil)
        return true
      case "v":
        paste(nil)
        return true
      case "a":
        selectAll(nil)
        return true
      case "k":
        onClearBuffer?()
        return true
      case ",":
        onOpenSettings?()
        return true
      default: break
      }
    } else if mods == [.command, .shift], key == "r" {
      onResetSession?()
      return true
    }
    return super.performKeyEquivalent(with: event)
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

    return menu
  }

  @objc private func menuClearBuffer() { onClearBuffer?() }
  @objc private func menuResetSession() { onResetSession?() }
}

final class TerminalViewController: NSViewController {

  private(set) var terminalView: SwifttyTerminalView!

  weak var eventSink: TerminalEventSink?

  private var isResetting = false

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
    startShell()
  }

  private func buildTerminal() {
    let term = SwifttyTerminalView(frame: view.bounds)
    term.translatesAutoresizingMaskIntoConstraints = false
    term.wantsLayer = true

    term.onBell = { [weak self] in
      self?.eventSink?.terminalDidRingBell()
    }
    term.onProcessExit = { [weak self] in
      guard let self, !self.isResetting else { return }
      self.startShell()
      self.focusTerminal()
    }
    term.onClearBuffer = { [weak self] in self?.clearBuffer() }
    term.onResetSession = { [weak self] in self?.resetSession() }
    term.onOpenSettings = { [weak self] in self?.eventSink?.terminalDidRequestSettings() }

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

    terminalView.getTerminal().updateFullScreen()
    terminalView.needsDisplay = true
  }

  // MARK: - Shell lifecycle

  private func startShell() {
    let shell = Preferences.shared.resolvedShellPath
    let shellName = (shell as NSString).lastPathComponent

    var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
    env.removeAll { $0.hasPrefix("TERM=") || $0.hasPrefix("PATH=") || $0.hasPrefix("SHELL=") }
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
    for entry in inherited + defaults where seen.insert(entry).inserted {
      ordered.append(entry)
    }
    return ordered.joined(separator: ":")
  }

  // MARK: - Resize

  override func viewDidLayout() {
    super.viewDidLayout()
    terminalView?.frame = view.bounds
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
