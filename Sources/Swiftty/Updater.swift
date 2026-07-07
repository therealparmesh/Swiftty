import Foundation
import Sparkle

@MainActor
final class Updater {

  static var isSupported: Bool {
    Bundle.main.bundleURL.pathExtension == "app"
  }

  private let controller: SPUStandardUpdaterController

  init() {
    controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
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
