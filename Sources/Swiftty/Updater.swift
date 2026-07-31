import AppKit
@preconcurrency import Sparkle

@MainActor
final class Updater: NSObject {

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

extension Updater: @MainActor SPUStandardUserDriverDelegate {

  var supportsGentleScheduledUpdateReminders: Bool { true }

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
