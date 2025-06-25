import UserNotifications

class NotificationService {
  private let notificationCenter = UNUserNotificationCenter.current()

  func requestAuthorization(completion: @escaping (Bool) -> Void) {
    notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
      DispatchQueue.main.async {
        if let error = error {
          print("Notification authorization error: \(error.localizedDescription)")
          completion(false)
          return
        }
        completion(granted)
      }
    }
  }

  func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
    notificationCenter.getNotificationSettings { settings in
      DispatchQueue.main.async {
        completion(settings.authorizationStatus)
      }
    }
  }

  func sendNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = UNNotificationSound.default

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil)

    notificationCenter.add(request) { error in
      if let error = error {
        print("Error sending notification: \(error.localizedDescription)")
      }
    }
  }

  func sendNotification(title: String, body: String, soundFileName: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body

    // Use custom sound file from the app bundle
    content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundFileName))

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil)

    notificationCenter.add(request) { error in
      if let error = error {
        print("Error sending notification: \(error.localizedDescription)")
      }
    }
  }

  func sendNotification(title: String, body: String, soundFileName: String?, enableSound: Bool) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body

    // Set sound based on enableSound setting and availability of sound file
    if enableSound, let soundFileName = soundFileName {
      content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundFileName))
    } else if enableSound {
      content.sound = UNNotificationSound.default
    } else {
      content.sound = nil
    }

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil)

    notificationCenter.add(request) { error in
      if let error = error {
        print("Error sending notification: \(error.localizedDescription)")
      }
    }
  }
}
