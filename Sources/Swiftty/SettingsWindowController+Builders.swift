import AppKit

extension SettingsWindowController {

  func section(_ title: String, _ views: [NSView]) -> NSStackView {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.textColor = TerminalTheme.tokyoNight.foreground

    let stack = NSStackView(views: [label] + views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 6
    stack.translatesAutoresizingMaskIntoConstraints = false

    for view in views {
      view.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
      let isCheckbox = view is NSButton && !(view is NSPopUpButton)
      if !isCheckbox {
        view.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
      }
    }
    return stack
  }

  func sliderRow(_ slider: NSSlider, _ valueLabel: NSTextField) -> NSView {
    let row = NSStackView(views: [slider, valueLabel])
    row.orientation = .horizontal
    row.spacing = 12
    row.translatesAutoresizingMaskIntoConstraints = false
    valueLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
    slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return row
  }

  func fontSizeRow(
    _ decreaseButton: NSButton,
    _ slider: NSSlider,
    _ increaseButton: NSButton,
    _ valueLabel: NSTextField
  ) -> NSView {
    let row = NSStackView(views: [decreaseButton, slider, increaseButton, valueLabel])
    row.orientation = .horizontal
    row.spacing = 8
    row.translatesAutoresizingMaskIntoConstraints = false
    valueLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
    slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return row
  }

  func configureFontSizeButton(
    _ button: NSButton,
    symbol: String,
    label: String,
    action: Selector
  ) {
    button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
    button.imagePosition = .imageOnly
    button.bezelStyle = .rounded
    button.bezelColor = TerminalTheme.tokyoNight.surface
    button.target = self
    button.action = action
    button.toolTip = label
    button.setAccessibilityLabel(label)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.widthAnchor.constraint(equalToConstant: 28).isActive = true
  }

  func configureSlider(_ slider: NSSlider, min: CGFloat, max: CGFloat, action: Selector) {
    slider.minValue = Double(min)
    slider.maxValue = Double(max)
    slider.target = self
    slider.action = action
    slider.isContinuous = true
    slider.trackFillColor = TerminalTheme.tokyoNight.accent
    slider.translatesAutoresizingMaskIntoConstraints = false
  }

  func bottomButton(_ title: String, _ action: Selector) -> NSButton {
    let button = NSButton(title: title, target: self, action: action)
    button.bezelStyle = .rounded
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }

  func configureValueLabel(_ label: NSTextField) {
    label.alignment = .right
    label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    label.textColor = TerminalTheme.tokyoNight.dim
    label.translatesAutoresizingMaskIntoConstraints = false
  }
}

// MARK: - Presentation

extension SettingsWindowController {

  /// The window is not resizable, so the constraints decide how tall it is.
  func resizeToFit() {
    guard let content = window?.contentView else { return }
    content.layoutSubtreeIfNeeded()
    window?.setContentSize(content.fittingSize)
  }

  func show() {
    syncFromPreferences()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    window?.makeFirstResponder(nil)
  }
}
