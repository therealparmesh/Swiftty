import AppKit

extension SettingsWindowController {

  func section(_ title: String, _ views: [NSView]) -> NSStackView {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .semibold)

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

  func configureSlider(_ slider: NSSlider, min: CGFloat, max: CGFloat, action: Selector) {
    slider.minValue = Double(min)
    slider.maxValue = Double(max)
    slider.target = self
    slider.action = action
    slider.isContinuous = true
    slider.translatesAutoresizingMaskIntoConstraints = false
  }

  func configureValueLabel(_ label: NSTextField) {
    label.alignment = .right
    label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    label.textColor = .secondaryLabelColor
    label.translatesAutoresizingMaskIntoConstraints = false
  }
}

// MARK: - Presentation

extension SettingsWindowController {

  func show() {
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    window?.makeFirstResponder(nil)
  }
}
