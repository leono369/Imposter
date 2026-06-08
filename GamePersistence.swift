import Foundation

final class GamePersistence {
  private let defaults: UserDefaults
  private let saveKey: String

  init(
    defaults: UserDefaults = .standard,
    saveKey: String = "imposter_v2_swift"
  ) {
    self.defaults = defaults
    self.saveKey = saveKey
  }

  func load() -> GameSave? {
    guard let data = defaults.data(forKey: saveKey) else {
      return nil
    }

    return try? JSONDecoder().decode(GameSave.self, from: data)
  }

  func save(_ game: GameSave) {
    guard let data = try? JSONEncoder().encode(game) else {
      return
    }

    defaults.set(data, forKey: saveKey)
  }

  func delete() {
    defaults.removeObject(forKey: saveKey)
  }
}
