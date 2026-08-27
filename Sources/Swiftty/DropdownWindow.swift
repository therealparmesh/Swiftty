import AppKit

/// The frosted panel that slides down from the top of the screen.
///
/// It has no title bar and no buttons. It knows two positions: parked above the
/// screen, and open under the menu bar. `AppDelegate` animates between them.
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

  /// A borderless window refuses the keyboard until it says otherwise.
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  // MARK: - Chrome

  private func configureWindowChrome() {
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    appearance = NSAppearance(named: .darkAqua)

    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true

    level = .floating

    // Follow the user to every Space, stay put over full-screen apps, and stay
    // out of Command-Tab.
    collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
      .ignoresCycle
    ]

    isReleasedWhenClosed = false
    hidesOnDeactivate = false
    isRestorable = false
    // The slide is animated by hand, so AppKit must not add its own animation.
    animationBehavior = .none
    isMovable = false
  }

  private func configureGlass() {
    guard let content = contentView else { return }
    content.wantsLayer = true

    let radius: CGFloat = 12
    content.layer?.cornerRadius = radius
    // Only the bottom corners are ever on screen, so only those are rounded.
    content.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    content.layer?.masksToBounds = true

    visualEffectView.frame = content.bounds
    content.addSubview(visualEffectView)
  }

  // MARK: - Geometry

  func deployedFrame(on screen: NSScreen) -> NSRect {
    Self.deployedFrame(
      fullFrame: screen.frame,
      visibleFrame: screen.visibleFrame,
      heightFraction: heightFraction
    )
  }

  /// The open position: the full width of the screen, hanging from the bottom of
  /// the menu bar.
  ///
  /// The width comes from the whole screen, but the height comes from the part
  /// the menu bar and the Dock leave free.
  static func deployedFrame(
    fullFrame: NSRect,
    visibleFrame: NSRect,
    heightFraction: CGFloat
  ) -> NSRect {
    let height = (visibleFrame.height * heightFraction).rounded()
    return NSRect(
      x: fullFrame.minX,
      y: visibleFrame.maxY - height,
      width: fullFrame.width,
      height: height
    )
  }

  /// The parked position: the same size, but pushed above the top edge.
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
