import AppKit

final class DropdownWindow: NSWindow {

  let visualEffectView: NSVisualEffectView

  var heightFraction: CGFloat = Preferences.defaultHeightFraction

  private(set) var isDeployed: Bool = false

  // MARK: - Init

  init() {
    let effect = NSVisualEffectView(frame: .zero)
    effect.material = .hudWindow
    effect.blendingMode = .behindWindow
    effect.state = .active
    effect.wantsLayer = true
    effect.autoresizingMask = [.width, .height]
    self.visualEffectView = effect

    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 200),
      styleMask: [.borderless, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    configureWindowChrome()
    configureGlass()
  }

  // MARK: - Key/Main eligibility

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  // MARK: - Chrome

  private func configureWindowChrome() {
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true

    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true

    level = .popUpMenu

    collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
      .ignoresCycle
    ]

    isReleasedWhenClosed = false
    hidesOnDeactivate = false
    isRestorable = false
    animationBehavior = .none
    isMovable = false
  }

  private func configureGlass() {
    guard let content = contentView else { return }
    content.wantsLayer = true

    let radius: CGFloat = 12
    content.layer?.cornerRadius = radius
    content.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    content.layer?.masksToBounds = true

    visualEffectView.frame = content.bounds
    content.addSubview(visualEffectView)
  }

  // MARK: - Geometry

  func deployedFrame(on screen: NSScreen) -> NSRect {
    let full = screen.frame
    let visible = screen.visibleFrame
    let height = (visible.height * heightFraction).rounded()
    return NSRect(
      x: full.minX,
      y: full.maxY - height,
      width: full.width,
      height: height
    )
  }

  func retractedFrame(on screen: NSScreen) -> NSRect {
    var frame = deployedFrame(on: screen)
    frame.origin.y = screen.frame.maxY
    return frame
  }

  func layout(on screen: NSScreen) {
    setFrame(retractedFrame(on: screen), display: false)
    visualEffectView.frame = contentView?.bounds ?? .zero
  }

  func markDeployed(_ deployed: Bool) {
    isDeployed = deployed
  }

  func applyOpacity(_ opacity: CGFloat) {
    alphaValue = opacity
  }
}
