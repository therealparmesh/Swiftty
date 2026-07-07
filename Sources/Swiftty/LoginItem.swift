import Foundation
import ServiceManagement

enum LoginItem {

  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  static var requiresApproval: Bool {
    SMAppService.mainApp.status == .requiresApproval
  }

  static func setEnabled(_ enabled: Bool) throws {
    let service = SMAppService.mainApp
    if enabled {
      if service.status != .enabled {
        try service.register()
      }
    } else {
      if service.status == .enabled {
        try service.unregister()
      }
    }
  }
}
