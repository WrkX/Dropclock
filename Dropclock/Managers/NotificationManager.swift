import Foundation
import UserNotifications

class NotificationManager {
  static let shared = NotificationManager()

  private init() {}

  func checkForPermission(completion: @escaping () -> Void = {}) {
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized:
        completion()
      case .denied:
        return
      case .notDetermined:
        notificationCenter.requestAuthorization(options: [.alert, .sound]) {
          didAllow, error in
          if didAllow {
            completion()
          }
        }
      default:
        return
      }
    }
  }

  func dispatchNotification(timerName: String? = nil) {
    let idenfier = UUID().uuidString
    let title = timerName ?? "Timer up"
    let body: String
    if let timerName = timerName {
      body = "Your timer \"\(timerName)\" has finished!"
    } else {
      body = "Your timer has finished!"
    }

    let notificationCenter = UNUserNotificationCenter.current()

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = UNNotificationSound.default
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: 0.1, repeats: false)
    let request = UNNotificationRequest(
      identifier: idenfier, content: content, trigger: trigger)

    notificationCenter.removeDeliveredNotifications(withIdentifiers: [idenfier])
    notificationCenter.add(request)
  }

  func getNotificationSettings(
    completion: @escaping (UNNotificationSettings) -> Void
  ) {
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.getNotificationSettings { settings in
      DispatchQueue.main.async {
        completion(settings)
      }
    }
  }
}
