import Combine
import Foundation
import UserNotifications

class JustLockInViewModel: ObservableObject {
  @Published var formattedTimeString: String
  @Published var timerState: TimerState = .idle
  @Published var settings: SettingsModel {
    didSet {
      persistenceService.saveSettings(settings)

      // Apply duration changes immediately if timer is idle
      if timerState == .idle {
        // Update the remaining time to match the new duration for the current session type
        let newDuration = totalDurationForSession(type: currentSessionType)
        remainingTime = newDuration
        progress = 0.0
        updateFormattedTime()
        onStatusUpdate?()
      }
    }
  }
  @Published var progress: Double = 0.0
  @Published var currentSessionType: SessionType = .work

  // For notification permissions
  @Published var canEnableNotifications = true
  @Published var shouldShowPermissionAlert = false

  private var timer: Timer?
  private let persistenceService = PersistenceService()
  private let notificationService = NotificationService()
  private var remainingTime: TimeInterval
  var completedWorkSessions: Int = 0

  private var sessionHistory: [SessionType] = []

  var onStatusUpdate: (() -> Void)?

  var canRewindToPreviousSession: Bool {
    return !sessionHistory.isEmpty
  }

  var rewindMenuItemTitle: String {
    if timerState == .idle {
      return "Go to Previous Session"
    } else {
      return "Reset Session"
    }
  }

  init() {
    let loadedSettings = persistenceService.loadSettings()
    self.settings = loadedSettings
    self.remainingTime = loadedSettings.workSessionDuration
    self.formattedTimeString = "25:00"  // Initial value
    updateFormattedTime()
    checkInitialNotificationStatus()
  }

  let durationFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.minimum = 0
    return formatter
  }()

  let sessionsFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .none
    formatter.minimum = 1
    formatter.maximum = 12
    return formatter
  }()


  /// Returns a user-friendly description of what the primary action (left-click) will do
  var primaryActionDescription: String {
    switch currentSessionType {
    case .overflow:
      return "Start Break"
    default:
      return timerState == .running ? "Pause" : "Start"
    }
  }

  /// Returns a more detailed description for UI hints
  var primaryActionHint: String {
    switch currentSessionType {
    case .overflow:
      return "Tap to start your break"
    case .work:
      return timerState == .running ? "Tap to pause work session" : "Tap to start work session"
    case .shortBreak:
      return timerState == .running ? "Tap to pause break" : "Tap to start short break"
    case .longBreak:
      return timerState == .running ? "Tap to pause break" : "Tap to start long break"
    }
  }

  func startTapped() {
    if timerState == .running {
      timerState = .paused
      timer?.invalidate()
    } else {
      timerState = .running
      startTimer()
    }
    onStatusUpdate?()
  }

  func skipTapped() {
    timer?.invalidate()
    // Manually transition from overflow to a break
    if currentSessionType == .overflow {
      // Add current session to history before transitioning
      sessionHistory.append(currentSessionType)

      completedWorkSessions += 1
      currentSessionType =
        (completedWorkSessions % settings.sessionsBeforeLongBreak == 0) ? .longBreak : .shortBreak
      remainingTime = totalDurationForSession(type: currentSessionType)

      // Respect auto-start setting when transitioning from overflow to break
      if settings.enableAutoStart {
        timerState = .running
        updateProgress()
        updateFormattedTime()
        onStatusUpdate?()
        startTimer()
      } else {
        timerState = .idle
        updateProgress()
        updateFormattedTime()
        onStatusUpdate?()
      }
    } else {
      startNextSession()
    }
  }

  func rewindOrResetTapped() {
    if timerState == .running || timerState == .paused {
      timer?.invalidate()
      timerState = .idle
      progress = 0.0
      remainingTime = totalDurationForSession(type: currentSessionType)
      updateFormattedTime()
      onStatusUpdate?()
    } else if timerState == .idle {
      rewindToPreviousSession()
    }
  }

  private func rewindToPreviousSession() {
    // Check if there's a previous session to rewind to
    guard let previousSession = sessionHistory.popLast() else {
      return  // No session to rewind to
    }

    if currentSessionType == .shortBreak || currentSessionType == .longBreak {
      completedWorkSessions = max(0, completedWorkSessions - 1)
    }

    currentSessionType = previousSession

    // Reset the timer with the duration for the previous session
    timerState = .idle
    progress = 0.0
    remainingTime = totalDurationForSession(type: currentSessionType)
    updateFormattedTime()
    onStatusUpdate?()
  }

  func resetTapped() {
    timer?.invalidate()
    timerState = .idle
    progress = 0.0
    currentSessionType = .work
    remainingTime = settings.workSessionDuration
    updateFormattedTime()
    onStatusUpdate?()
  }

  func restartAll() {
    timer?.invalidate()
    timerState = .idle
    progress = 0.0
    currentSessionType = .work
    completedWorkSessions = 0
    sessionHistory.removeAll()  // Clear session history
    remainingTime = settings.workSessionDuration
    updateFormattedTime()
    onStatusUpdate?()
  }

  func resetSettingsToDefaults() {
    // Create a new SettingsModel with default values
    let defaultSettings = SettingsModel()

    settings = defaultSettings

    // Reset timer state if needed
    if timerState == .idle {
      currentSessionType = .work
      remainingTime = settings.workSessionDuration
      progress = 0.0
      updateFormattedTime()
      onStatusUpdate?()
    }
  }

  func notificationSettingChanged(isEnabled: Bool) {
    if isEnabled {
      // User wants to enable notifications - request permission
      notificationService.requestAuthorization { [weak self] granted in
        guard let self = self else { return }
        DispatchQueue.main.async {
          if !granted {
            // Permission denied - revert toggle and show alert
            self.settings.enableNotifications = false
            self.shouldShowPermissionAlert = true
          }
        }
      }
    }
  }

  private func checkInitialNotificationStatus() {
    notificationService.checkAuthorizationStatus { [weak self] status in
      DispatchQueue.main.async {
        switch status {
        case .denied:
          // Only disable if explicitly denied and user has tried before
          if self?.settings.enableNotifications == true {
            self?.settings.enableNotifications = false
          }
          self?.canEnableNotifications = true  // Still allow user to try
        case .authorized, .notDetermined, .provisional, .ephemeral:
          self?.canEnableNotifications = true
        @unknown default:
          self?.canEnableNotifications = true
        }
      }
    }
  }

  private func startTimer() {
    timer = Timer.scheduledTimer(
      timeInterval: 1.0, target: self, selector: #selector(timerFired), userInfo: nil,
      repeats: true)
  }

  @objc private func timerFired() {
    if currentSessionType == .overflow {
      remainingTime += 1
      updateFormattedTime()
      onStatusUpdate?()
      return
    }

    if remainingTime > 1 {
      remainingTime -= 1
      updateProgress()
      updateFormattedTime()
    } else {
      timer?.invalidate()
      timerState = .idle

      switch currentSessionType {
      case .work:
        if settings.enableNotifications {
          let duration = settings.workSessionDuration
          notificationService.sendNotification(
            title: "Time for a break!",
            body: "Your \(Int(duration / 60))-minute focus session is complete.",
            soundFileName: "work-noti.wav",
            enableSound: settings.enableSoundNotifications)
        }

        // Check if overflow mode is enabled
        if settings.enableOverflowMode {
          // Add current session to history before transitioning to overflow
          sessionHistory.append(currentSessionType)

          // Auto-transition to overflow mode
          currentSessionType = .overflow
          remainingTime = 0
          timerState = .running
          updateProgress()
          updateFormattedTime()
          startTimer()  // Always start overflow timer immediately
          onStatusUpdate?()
          return
        } else {
          startNextSession()
        }

      case .shortBreak, .longBreak:
        if settings.enableNotifications {
          let duration = totalDurationForSession(type: currentSessionType)
          notificationService.sendNotification(
            title: "Back to focus!",
            body: "Your \(Int(duration / 60))-minute break is over.",
            soundFileName: "work-noti.wav",
            enableSound: settings.enableSoundNotifications)
        }
        startNextSession()
      case .overflow:
        break
      }
    }
  }

  private func startNextSession() {
    let previousSession = currentSessionType

    // Add the current session to history before transitioning
    sessionHistory.append(previousSession)

    if previousSession == .work {
      completedWorkSessions += 1
    }

    if previousSession == .shortBreak || previousSession == .longBreak {
      currentSessionType = .work
    } else {
      currentSessionType =
        (completedWorkSessions % settings.sessionsBeforeLongBreak == 0) ? .longBreak : .shortBreak
    }

    remainingTime = totalDurationForSession(type: currentSessionType)
    progress = 1.0

    if settings.enableAutoStart {
      timerState = .running
      updateProgress()
      updateFormattedTime()
      onStatusUpdate?()
      startTimer()
    } else {
      timerState = .idle
      updateProgress()
      updateFormattedTime()
      onStatusUpdate?()
    }
  }

  private func totalDurationForSession(type: SessionType) -> TimeInterval {
    switch type {
    case .work:
      return settings.workSessionDuration
    case .shortBreak:
      return settings.shortBreakDuration
    case .longBreak:
      return settings.longBreakDuration
    case .overflow:
      return 0
    }
  }

  private func updateFormattedTime() {
    let minutes = Int(remainingTime) / 60
    let seconds = Int(remainingTime) % 60
    formattedTimeString = String(format: "%02d:%02d", minutes, seconds)
    onStatusUpdate?()
  }

  private func updateProgress() {
    let totalDuration = totalDurationForSession(type: currentSessionType)
    if totalDuration > 0 {
      progress = 1.0 - (remainingTime / totalDuration)
    } else {
      progress = 0.0
    }
  }
}
