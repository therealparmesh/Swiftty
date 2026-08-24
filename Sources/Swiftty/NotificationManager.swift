import AppKit
@preconcurrency import UserNotifications

@MainActor
final class NotificationManager: NSObject {

  static let shared = NotificationManager()

  private let center = UNUserNotificationCenter.current()
  private var lastFired: Date = .distantPast
  private let coalesceInterval: TimeInterval = 2.0

  private override init() {
    super.init()
    center.delegate = self
  }

  /// Asked for at launch, so the prompt does not surprise anyone on the first bell.
  func requestAuthorization() {
    Self.requestAuthorization(center: center)
  }

  private nonisolated static func requestAuthorization(center: UNUserNotificationCenter) {
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  func notifyBell() {
    let now = Date()
    guard now.timeIntervalSince(lastFired) >= coalesceInterval else { return }
    lastFired = now

    Self.getNotificationSettings(center: center) { [weak self] granted in
      guard granted else { return }
      self?.deliverBellBanner(at: now)
    }
  }

  private nonisolated static func getNotificationSettings(
    center: UNUserNotificationCenter,
    completion: @escaping @MainActor (Bool) -> Void
  ) {
    center.getNotificationSettings { settings in
      let granted = settings.authorizationStatus == .authorized
      Task { @MainActor in completion(granted) }
    }
  }

  private func deliverBellBanner(at date: Date) {
    let content = UNMutableNotificationContent()
    content.title = "Swiftty"
    content.body = "The terminal rang while Swiftty was hidden."
    content.sound = .default
    content.interruptionLevel = .active

    let request = UNNotificationRequest(
      identifier: "com.parmscript.swiftty.bell.\(date.timeIntervalSince1970)",
      content: content,
      trigger: nil
    )
    center.add(request, withCompletionHandler: nil)
  }
}

extension NotificationManager: UNUserNotificationCenterDelegate {

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    DispatchQueue.main.async {
      (NSApp.delegate as? AppDelegate)?.deployFromExternalTrigger()
    }
    completionHandler()
  }
}
