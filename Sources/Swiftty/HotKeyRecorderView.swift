import AppKit
import Carbon.HIToolbox
import HotKey

final class HotKeyRecorderView: NSControl {

  var onCapture: ((KeyCombo) -> Void)?
  var onRecordingChanged: ((Bool) -> Void)?

  var displayedCombo: KeyCombo? {
    didSet { needsDisplay = true }
  }

  private var isRecording = false {
    didSet {
      guard isRecording != oldValue else { return }
      needsDisplay = true
      onRecordingChanged?(isRecording)
    }
  }

  // MARK: - Init

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configure()
  }

  private func configure() {
    wantsLayer = true
    layer?.cornerRadius = 6
    layer?.borderWidth = 1
    setAccessibilityRole(.button)
    setAccessibilityLabel("Shortcut recorder")
    setAccessibilityHelp("Click to record a shortcut. Esc cancels.")
  }

  // MARK: - Focus

  override var acceptsFirstResponder: Bool { true }
  override var canBecomeKeyView: Bool { true }

  override func becomeFirstResponder() -> Bool {
    isRecording = true
    return super.becomeFirstResponder()
  }

  override func resignFirstResponder() -> Bool {
    isRecording = false
    return super.resignFirstResponder()
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
  }

  // MARK: - Key capture

  override func keyDown(with event: NSEvent) {
    guard isRecording else {
      super.keyDown(with: event)
      return
    }

    if event.keyCode == UInt16(kVK_Escape) {
      window?.makeFirstResponder(nil)
      return
    }

    let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let combo = KeyCombo(
      carbonKeyCode: UInt32(event.keyCode),
      carbonModifiers: mods.carbonFlags)

    guard combo.key != nil else { return }

    displayedCombo = combo
    onCapture?(combo)
    window?.makeFirstResponder(nil)
  }

  override func flagsChanged(with event: NSEvent) {
    if !isRecording { super.flagsChanged(with: event) }
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if isRecording {
      keyDown(with: event)
      return true
    }
    return super.performKeyEquivalent(with: event)
  }

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let accent = NSColor.controlAccentColor
    layer?.borderColor = (isRecording ? accent : NSColor.separatorColor).cgColor
    layer?.backgroundColor =
      (isRecording
      ? accent.withAlphaComponent(0.12)
      : NSColor.controlBackgroundColor).cgColor

    let text: String
    if isRecording {
      text = "Press a shortcut. Esc cancels."
    } else {
      text = displayedCombo?.description ?? "Click to record"
    }

    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 13, weight: .medium),
      .foregroundColor: isRecording ? accent : NSColor.labelColor,
      .paragraphStyle: style
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let size = attributed.size()
    let rect = NSRect(
      x: 0,
      y: (bounds.height - size.height) / 2,
      width: bounds.width,
      height: size.height
    )
    attributed.draw(in: rect)
  }
}
