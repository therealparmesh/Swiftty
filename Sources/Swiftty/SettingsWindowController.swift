import AppKit
import HotKey

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

  private let recorder = HotKeyRecorderView()
  private let statusLabel = NSTextField(labelWithString: "")
  private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
  private let loginStatusLabel = NSTextField(labelWithString: "")
  private let autoUpdateCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
  private let shellPopup = NSPopUpButton()
  private let fontPopup = NSPopUpButton()
  private let fontSizeSlider = NSSlider()
  private let fontSizeValueLabel = NSTextField(labelWithString: "")
  private let heightSlider = NSSlider()
  private let heightValueLabel = NSTextField(labelWithString: "")
  private let opacitySlider = NSSlider()
  private let opacityValueLabel = NSTextField(labelWithString: "")

  private var shellPaths: [String] = []
  private var fontFamilies: [String] = []
  private var updater: Updater?

  var onRecordingChanged: ((Bool) -> Void)?

  convenience init(updater: Updater?) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Swiftty Settings"
    window.isReleasedWhenClosed = false
    window.level = .popUpMenu
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.center()
    self.init(window: window)
    self.updater = updater
    window.delegate = self
    buildUI()
    syncFromPreferences()
  }

  // MARK: - UI construction

  private func configureControls() {
    recorder.onCapture = { [weak self] combo in self?.handleRecorded(combo) }
    recorder.onRecordingChanged = { [weak self] recording in
      self?.onRecordingChanged?(recording)
    }
    recorder.heightAnchor.constraint(equalToConstant: 34).isActive = true

    statusLabel.font = .systemFont(ofSize: 11)
    statusLabel.textColor = .secondaryLabelColor
    statusLabel.lineBreakMode = .byWordWrapping
    statusLabel.maximumNumberOfLines = 2
    statusLabel.cell?.wraps = true

    launchAtLoginCheckbox.title = "Launch Swiftty at login"
    launchAtLoginCheckbox.target = self
    launchAtLoginCheckbox.action = #selector(launchAtLoginToggled)

    loginStatusLabel.font = .systemFont(ofSize: 11)
    loginStatusLabel.textColor = .secondaryLabelColor
    loginStatusLabel.lineBreakMode = .byWordWrapping
    loginStatusLabel.maximumNumberOfLines = 2
    loginStatusLabel.cell?.wraps = true
    loginStatusLabel.isHidden = true

    autoUpdateCheckbox.title = "Check for updates automatically"
    autoUpdateCheckbox.target = self
    autoUpdateCheckbox.action = #selector(autoUpdateToggled)

    shellPopup.target = self
    shellPopup.action = #selector(shellChanged)

    fontPopup.target = self
    fontPopup.action = #selector(fontChanged)

    configureSlider(fontSizeSlider, min: Preferences.minFontSize, max: Preferences.maxFontSize,
                    action: #selector(fontSizeChanged))
    configureSlider(heightSlider, min: Preferences.minHeightFraction, max: Preferences.maxHeightFraction,
                    action: #selector(heightChanged))
    configureSlider(opacitySlider, min: Preferences.minOpacity, max: Preferences.maxOpacity,
                    action: #selector(opacityChanged))
    configureValueLabel(fontSizeValueLabel)
    configureValueLabel(heightValueLabel)
    configureValueLabel(opacityValueLabel)
  }

  private func buildUI() {
    guard let content = window?.contentView else { return }
    configureControls()

    var generalControls: [NSView] = [launchAtLoginCheckbox, loginStatusLabel]
    if updater != nil {
      generalControls.insert(autoUpdateCheckbox, at: 1)
    }

    let sectionStacks = [
      section("General", generalControls),
      section("Shortcut", [recorder, statusLabel]),
      section("Shell", [shellPopup]),
      section("Font", [fontPopup, sliderRow(fontSizeSlider, fontSizeValueLabel)]),
      section("Window Height", [sliderRow(heightSlider, heightValueLabel)]),
      section("Background Opacity", [sliderRow(opacitySlider, opacityValueLabel)])
    ]
    let sections = NSStackView(views: sectionStacks)
    sections.orientation = .vertical
    sections.alignment = .leading
    sections.spacing = 18
    sections.translatesAutoresizingMaskIntoConstraints = false

    let restoreButton = NSButton(title: "Restore Defaults", target: self,
                                 action: #selector(restoreDefaults))
    restoreButton.bezelStyle = .rounded
    restoreButton.translatesAutoresizingMaskIntoConstraints = false

    let doneButton = NSButton(title: "Done", target: self, action: #selector(closeWindow))
    doneButton.bezelStyle = .rounded
    doneButton.keyEquivalent = "\r"
    doneButton.translatesAutoresizingMaskIntoConstraints = false

    content.addSubview(sections)
    content.addSubview(restoreButton)
    content.addSubview(doneButton)

    NSLayoutConstraint.activate([
      sections.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
      sections.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
      sections.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

      restoreButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
      restoreButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),

      doneButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
      doneButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
      doneButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
    ])

    for stack in sectionStacks {
      stack.widthAnchor.constraint(equalTo: sections.widthAnchor).isActive = true
    }
  }

  // MARK: - Sync

  private func syncFromPreferences() {
    let prefs = Preferences.shared
    updateLoginStatus()
    if let updater {
      autoUpdateCheckbox.state = updater.automaticallyChecksForUpdates ? .on : .off
    }
    recorder.displayedCombo = prefs.keyCombo
    rebuildShellPopup(selected: prefs.shellPath)
    rebuildFontPopup(selected: prefs.fontName)
    fontSizeSlider.doubleValue = Double(prefs.fontSize)
    updateFontSizeLabel(prefs.fontSize)
    heightSlider.doubleValue = Double(prefs.heightFraction)
    updateHeightLabel(prefs.heightFraction)
    opacitySlider.doubleValue = Double(prefs.opacity)
    updateOpacityLabel(prefs.opacity)
    showValidationResult(.valid, committed: true)
  }

  private func rebuildShellPopup(selected: String?) {
    shellPopup.removeAllItems()
    let systemDefault = Preferences.systemLoginShell()
    shellPopup.addItem(withTitle: "System Default (\(systemDefault))")

    shellPaths = ShellList.available()
    for path in shellPaths {
      shellPopup.addItem(withTitle: path)
    }

    if let selected, let index = shellPaths.firstIndex(of: selected) {
      shellPopup.selectItem(at: index + 1)
    } else {
      shellPopup.selectItem(at: 0)
    }
  }

  private func rebuildFontPopup(selected: String?) {
    fontPopup.removeAllItems()
    fontPopup.addItem(withTitle: "System Monospaced")

    fontFamilies = FontList.families()
    for family in fontFamilies {
      fontPopup.addItem(withTitle: family)
    }

    if let selected, let index = fontFamilies.firstIndex(of: selected) {
      fontPopup.selectItem(at: index + 1)
    } else {
      fontPopup.selectItem(at: 0)
    }
  }

  // MARK: - Actions

  private func handleRecorded(_ combo: KeyCombo) {
    let result = HotKeyValidator.validate(combo)
    switch result {
    case .valid:
      Preferences.shared.keyCombo = combo
      recorder.displayedCombo = combo
      showValidationResult(.valid, committed: false)
    case .invalid, .systemReserved:
      recorder.displayedCombo = Preferences.shared.keyCombo
      showValidationResult(result, committed: false)
    }
  }

  @objc private func launchAtLoginToggled() {
    do {
      try LoginItem.setEnabled(launchAtLoginCheckbox.state == .on)
      updateLoginStatus()
    } catch {
      updateLoginStatus(
        message: "Could not update login item. Check System Settings > General > Login Items.")
    }
  }

  private func updateLoginStatus(message: String? = nil) {
    launchAtLoginCheckbox.state = LoginItem.isEnabled ? .on : .off
    if let message {
      loginStatusLabel.textColor = .systemRed
      loginStatusLabel.stringValue = message
      loginStatusLabel.isHidden = false
      return
    }
    guard !LoginItem.requiresApproval else {
      loginStatusLabel.textColor = .systemOrange
      loginStatusLabel.stringValue =
        "Approve Swiftty in System Settings > General > Login Items."
      loginStatusLabel.isHidden = false
      return
    }
    loginStatusLabel.isHidden = true
  }

  @objc private func autoUpdateToggled() {
    updater?.automaticallyChecksForUpdates = autoUpdateCheckbox.state == .on
  }

  @objc private func shellChanged() {
    let index = shellPopup.indexOfSelectedItem
    Preferences.shared.shellPath = index <= 0 ? nil : shellPaths[index - 1]
  }

  @objc private func fontChanged() {
    let index = fontPopup.indexOfSelectedItem
    Preferences.shared.fontName = index <= 0 ? nil : fontFamilies[index - 1]
  }

  @objc private func fontSizeChanged() {
    Preferences.shared.fontSize = CGFloat(fontSizeSlider.doubleValue)
    updateFontSizeLabel(Preferences.shared.fontSize)
  }

  @objc private func heightChanged() {
    Preferences.shared.heightFraction = CGFloat(heightSlider.doubleValue)
    updateHeightLabel(Preferences.shared.heightFraction)
  }

  @objc private func opacityChanged() {
    Preferences.shared.opacity = CGFloat(opacitySlider.doubleValue)
    updateOpacityLabel(Preferences.shared.opacity)
  }

  @objc private func restoreDefaults() {
    Preferences.shared.restoreDefaults()
    syncFromPreferences()
  }

  @objc private func closeWindow() { window?.close() }

  // MARK: - Feedback

  private func updateFontSizeLabel(_ size: CGFloat) { fontSizeValueLabel.stringValue = pointText(size) }

  private func updateHeightLabel(_ fraction: CGFloat) { heightValueLabel.stringValue = percentText(fraction) }

  private func updateOpacityLabel(_ value: CGFloat) { opacityValueLabel.stringValue = percentText(value) }

  private func showValidationResult(_ result: HotKeyValidator.Result, committed: Bool) {
    switch result {
    case .valid:
      statusLabel.textColor = .secondaryLabelColor
      statusLabel.stringValue =
        committed
        ? "Press the shortcut anywhere to toggle Swiftty."
        : "Saved. Press the shortcut anywhere to toggle Swiftty."
    case .invalid(let reason), .systemReserved(let reason):
      statusLabel.textColor = .systemRed
      statusLabel.stringValue = reason
    }
  }

  // MARK: - NSWindowDelegate

  func windowWillClose(_ notification: Notification) {
    if window?.firstResponder === recorder {
      window?.makeFirstResponder(nil)
    }
  }
}

private func pointText(_ size: CGFloat) -> String { "\(Int(size.rounded())) pt" }
private func percentText(_ value: CGFloat) -> String { "\(Int((value * 100).rounded()))%" }
