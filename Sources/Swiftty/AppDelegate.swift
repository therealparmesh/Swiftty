import AppKit
import HotKey

@main
final class AppDelegate: NSObject, NSApplicationDelegate, TerminalEventSink {

  private var statusItem: NSStatusItem!
  private var hotKey: HotKey?
  private var registeredCombo: KeyCombo?
  private var activeShellPath: String?

  private let window = DropdownWindow()
  private var terminalController: TerminalViewController!
  private var settingsController: SettingsWindowController?
  private var updater: Updater?

  private var isAnimating = false

  private var globalClickMonitor: Any?
  private var resignObserver: NSObjectProtocol?
  private var screenObserver: NSObjectProtocol?
  private var prefsObserver: NSObjectProtocol?

  // MARK: - Lifecycle

  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    setUpStatusItem()
    setUpWindow()
    registerHotKey()
    setUpAutoRetract()
    observePreferences()
    if Updater.isSupported { updater = Updater() }
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
    for observer in [resignObserver, screenObserver, prefsObserver].compactMap({ $0 }) {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  // MARK: - Status bar

  private func setUpStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "terminal.fill",
        accessibilityDescription: "Swiftty"
      )
      button.image?.isTemplate = true
      button.toolTip = "Swiftty"
      button.target = self
      button.action = #selector(statusItemClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
  }

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    if NSApp.currentEvent?.type == .rightMouseUp {
      presentContextMenu()
    } else {
      toggle()
    }
  }

  private func presentContextMenu() {
    let menu = NSMenu()
    menu.addItem(
      menuItem(
        "Toggle Swiftty (\(Preferences.shared.keyCombo.description))",
        #selector(menuToggle)))
    menu.addItem(.separator())
    menu.addItem(menuItem("Settings...", #selector(openSettings), key: ","))
    if updater != nil {
      menu.addItem(menuItem("Check for Updates...", #selector(checkForUpdates)))
    }
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: "Quit Swiftty",
        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  private func menuItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = self
    return item
  }

  @objc private func menuToggle() { toggle() }
  @objc private func checkForUpdates() { updater?.checkForUpdates() }

  @objc private func openSettings() {
    if settingsController == nil {
      let controller = SettingsWindowController(updater: updater)
      controller.onRecordingChanged = { [weak self] recording in
        self?.hotKey?.isPaused = recording
      }
      settingsController = controller
    }
    settingsController?.show()
  }

  // MARK: - Window + terminal

  private func setUpWindow() {
    terminalController = TerminalViewController()
    terminalController.eventSink = self
    window.heightFraction = Preferences.shared.heightFraction
    window.applyOpacity(Preferences.shared.opacity)
    activeShellPath = Preferences.shared.resolvedShellPath

    let host = terminalController.view
    host.translatesAutoresizingMaskIntoConstraints = false
    window.visualEffectView.addSubview(host)
    NSLayoutConstraint.activate([
      host.leadingAnchor.constraint(equalTo: window.visualEffectView.leadingAnchor),
      host.trailingAnchor.constraint(equalTo: window.visualEffectView.trailingAnchor),
      host.topAnchor.constraint(equalTo: window.visualEffectView.topAnchor),
      host.bottomAnchor.constraint(equalTo: window.visualEffectView.bottomAnchor)
    ])

    window.layout(on: activeScreen())

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.repinGeometry() }
    }
  }

  private func repinGeometry() {
    let screen = activeScreen()
    if window.isDeployed {
      window.setFrame(window.deployedFrame(on: screen), display: true)
    } else {
      window.layout(on: screen)
    }
  }

  // MARK: - Global hotkey

  private func registerHotKey() {
    let combo = Preferences.shared.keyCombo
    guard combo != registeredCombo else { return }

    hotKey = nil
    let newHotKey = HotKey(keyCombo: combo)
    newHotKey.keyDownHandler = { [weak self] in
      MainActor.assumeIsolated { self?.toggle() }
    }
    hotKey = newHotKey
    registeredCombo = combo
    updateStatusItemTooltip()
  }

  private func updateStatusItemTooltip() {
    statusItem.button?.toolTip = "Swiftty: \(Preferences.shared.keyCombo.description) to toggle"
  }

  // MARK: - Preference observation

  private func observePreferences() {
    prefsObserver = NotificationCenter.default.addObserver(
      forName: Preferences.didChange,
      object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.registerHotKey()
        self.window.heightFraction = Preferences.shared.heightFraction
        self.repinGeometry()
        self.window.applyOpacity(Preferences.shared.opacity)
        self.terminalController.applyTheme()
        let shell = Preferences.shared.resolvedShellPath
        if shell != self.activeShellPath {
          self.activeShellPath = shell
          self.terminalController.resetSession()
        }
      }
    }
  }

  // MARK: - Slide animation

  private func activeScreen() -> NSScreen {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
      ?? NSScreen.main
      ?? NSScreen.screens.first!
  }

  func toggle() {
    guard !isAnimating else { return }
    if window.isDeployed {
      retract()
    } else {
      deploy()
    }
  }

  func deployFromExternalTrigger() {
    guard !window.isDeployed, !isAnimating else { return }
    deploy()
  }

  private func deploy() {
    let screen = activeScreen()
    let start = window.retractedFrame(on: screen)
    let end = window.deployedFrame(on: screen)

    window.setFrame(start, display: false)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    isAnimating = true
    NSAnimationContext.runAnimationGroup(
      { ctx in
        ctx.duration = 0.22
        ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
        window.animator().setFrame(end, display: true)
      },
      completionHandler: { [weak self] in
        MainActor.assumeIsolated {
          guard let self else { return }
          self.isAnimating = false
          self.window.markDeployed(true)
          self.terminalController.focusTerminal()
        }
      })
  }

  private func retract() {
    let screen = activeScreen()
    let end = window.retractedFrame(on: screen)

    isAnimating = true
    window.markDeployed(false)
    NSAnimationContext.runAnimationGroup(
      { ctx in
        ctx.duration = 0.20
        ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
        window.animator().setFrame(end, display: true)
      },
      completionHandler: { [weak self] in
        MainActor.assumeIsolated {
          guard let self else { return }
          self.isAnimating = false
          self.window.orderOut(nil)
        }
      })
  }

  // MARK: - Auto-retract

  private func setUpAutoRetract() {
    globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.shouldAutoRetract else { return }
        self.retract()
      }
    }

    resignObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didResignKeyNotification,
      object: window, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.shouldAutoRetract else { return }
        self.retract()
      }
    }
  }

  private var shouldAutoRetract: Bool {
    window.isDeployed && !isAnimating
  }

  // MARK: - TerminalEventSink

  func terminalDidRingBell() {
    if !window.isDeployed {
      NotificationManager.shared.notifyBell()
    }
  }

  func terminalDidRequestSettings() {
    openSettings()
  }
}
