import Foundation

class PersistenceService {
  private let settingsKey = "justLockInSettings"

  func saveSettings(_ settings: SettingsModel) {
    if let encoded = try? JSONEncoder().encode(settings) {
      UserDefaults.standard.set(encoded, forKey: settingsKey)
    }
  }

  func loadSettings() -> SettingsModel {
    if let data = UserDefaults.standard.data(forKey: settingsKey) {
      if let decoded = try? JSONDecoder().decode(SettingsModel.self, from: data) {
        return decoded
      }
    }
    return SettingsModel()
  }
}
