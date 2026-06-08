import Foundation

final class RoundBuilder {
  struct Result {
    let cards: [RoundCard]
    let wordNumber: Int
  }

  func build(
    playerCount: Int,
    playerName: (Int) -> String,
    selectedRoles: [String: Bool],
    categoryID: String
  ) -> Result? {
    guard let category = categories.first(where: { $0.id == categoryID }),
      !category.words.isEmpty
    else {
      return nil
    }

    let otherCategories = categories.filter {
      $0.id != categoryID && $0.words.count == category.words.count
    }
    let wordIndex = Int.random(in: category.words.indices)
    let word = category.words[wordIndex]
    var roles = makeRoles(
      playerCount: playerCount,
      selectedRoles: selectedRoles
    )
    roles.shuffle()

    let cards = roles.enumerated().map { index, role in
      makeCard(
        playerName: playerName(index),
        role: role,
        word: word,
        wordIndex: wordIndex,
        category: category,
        otherCategories: otherCategories
      )
    }

    return Result(cards: cards, wordNumber: wordIndex + 1)
  }

  private func makeRoles(
    playerCount: Int,
    selectedRoles: [String: Bool]
  ) -> [PlayerRole] {
    var roles: [PlayerRole] = [.imposter]

    if selectedRoles["saboteur"] == true {
      roles.append(.saboteur)
    }
    if selectedRoles["senior"] == true {
      roles.append(.senior)
    }
    if selectedRoles["doppelagent"] == true {
      roles.append(.doppelagent)
    }

    while roles.count < playerCount {
      roles.append(.crew)
    }

    return Array(roles.prefix(playerCount))
  }

  private func makeCard(
    playerName: String,
    role: PlayerRole,
    word: String,
    wordIndex: Int,
    category: WordCategory,
    otherCategories: [WordCategory]
  ) -> RoundCard {
    var display = word
    var subtitle = "Kategorie · \(category.name)"
    var secret = ""
    var isMasked = false

    switch role {
    case .imposter:
      display = "???"
      subtitle = "Du kennst den Begriff nicht"
    case .saboteur:
      secret = "Dein Ziel: lass dich als Imposter verdächtigen!"
    case .senior:
      display = mask(word)
      subtitle = "Lies genau hin …"
      isMasked = true
    case .doppelagent:
      if let otherCategory = otherCategories.randomElement() {
        display = otherCategory.words[wordIndex]
        subtitle = "Kategorie · \(otherCategory.name)"
      }
    case .crew:
      break
    }

    return RoundCard(
      name: playerName,
      role: role,
      display: display,
      sub: subtitle,
      secret: secret,
      masked: isMasked
    )
  }

  private func mask(_ word: String) -> String {
    var result = ""
    var isWordStart = true

    for character in word {
      if !character.isLetter {
        result.append(character)
        isWordStart = true
      } else if isWordStart {
        result.append(character)
        isWordStart = false
      } else {
        result.append(Bool.random() ? "_" : character)
      }
    }

    return result
  }
}
