import Foundation

enum SessionType {
  case work
  case shortBreak
  case longBreak
  case overflow
}

enum TimerState {
  case idle
  case running
  case paused
}

struct SettingsModel: Codable {
  var workSessionDuration: TimeInterval = 25 * 60
  var shortBreakDuration: TimeInterval = 5 * 60
  var longBreakDuration: TimeInterval = 15 * 60
  var sessionsBeforeLongBreak: Int = 4
  var enableNotifications: Bool = false
  var enableSoundNotifications: Bool = false
  var enableOverflowMode: Bool = true
  var enableAutoStart: Bool = false
  var showWelcomeAlert: Bool = true
}
