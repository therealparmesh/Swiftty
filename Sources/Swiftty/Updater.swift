import AppKit
@preconcurrency import Sparkle

/// Automatic updates, set up for an app that has no Dock icon.
///
/// Sparkle downloads a new build from the appcast named in `Info.plist`. Swiftty
/// only turns into a normal app while an update is on screen, then goes quiet
/// again.
@MainActor
final class Updater: NSObject {

  /// Sparkle needs a real `.app` bundle, so a plain `swift run` has no updater.
  static var isSupported: Bool {
    Bundle.main.bundleURL.pathExtension == "app"
  }

  private var controller: SPUStandardUpdaterController!

  override init() {
    super.init()
    controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: self
    )
  }

  func checkForUpdates() {
    controller.updater.checkForUpdates()
  }

  var automaticallyChecksForUpdates: Bool {
    get { controller.updater.automaticallyChecksForUpdates }
    set { controller.updater.automaticallyChecksForUpdates = newValue }
  }

}

// MARK: - SPUStandardUserDriverDelegate

extension Updater: @preconcurrency SPUStandardUserDriverDelegate {

  var supportsGentleScheduledUpdateReminders: Bool { true }

  /// An update window belongs to a normal app, so Swiftty takes a Dock tile for as
  /// long as the window is up. A badge marks an update the user did not ask for.
  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool,
    forUpdate update: SUAppcastItem,
    state: SPUUserUpdateState
  ) {
    NSApp.setActivationPolicy(.regular)
    if !state.userInitiated {
      NSApp.dockTile.badgeLabel = "1"
    }
  }

  func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
    NSApp.dockTile.badgeLabel = nil
  }

  func standardUserDriverWillFinishUpdateSession() {
    NSApp.dockTile.badgeLabel = nil
    NSApp.setActivationPolicy(.accessory)
  }
}
