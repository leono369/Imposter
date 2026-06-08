import SwiftUI

// MARK: - Models

struct WordCategory: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let words: [String]
}

struct SpecialRole: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let desc: String
}

enum PlayerRole: String, Codable {
  case imposter, saboteur, senior, doppelagent, crew

  var label: String {
    switch self {
    case .imposter: return "Imposter"
    case .saboteur: return "Saboteur"
    case .senior: return "Senior"
    case .doppelagent: return "Doppelagent"
    case .crew: return "Crew"
    }
  }
}

struct RoundCard: Identifiable, Codable, Hashable {
  let id: UUID
  var name: String
  var role: PlayerRole
  var display: String
  var sub: String
  var secret: String
  var masked: Bool

  init(name: String, role: PlayerRole, display: String, sub: String, secret: String, masked: Bool) {
    self.id = UUID()
    self.name = name
    self.role = role
    self.display = display
    self.sub = sub
    self.secret = secret
    self.masked = masked
  }
}

struct GameSave: Codable {
  var players: Int
  var names: [String]
  var roles: [String: Bool]
  var category: String
  var scores: [Int]
  var roundNumber: Int
  var assign: [RoundCard]
  var theNum: Int
}

// MARK: - Data

let categories: [WordCategory] = [
  WordCategory(
    id: "alltag", name: "Alltag",
    words: [
      "Backofen", "nass", "Ball", "Pony", "Kreuz", "UFO", "Traum",
      "Schlüssel", "Brücke", "Pfeil", "Tinte", "Feuer", "Messe",
      "Stuhl", "Selfie-Stick", "Aquarium", "Konzert", "Matcha Latte",
      "Französisch", "Schrank",
    ]),
  WordCategory(
    id: "tiere", name: "Tiere",
    words: [
      "Pinguin", "Elefant", "Hai", "Adler", "Fuchs", "Qualle", "Igel",
      "Koala", "Gepard", "Eule", "Wal", "Biene", "Krokodil", "Otter",
      "Flamingo", "Wolf", "Schmetterling", "Faultier", "Tintenfisch", "Reh",
    ]),
  WordCategory(
    id: "essen", name: "Essen",
    words: [
      "Pizza", "Sushi", "Brezel", "Avocado", "Lasagne", "Curry",
      "Pancakes", "Döner", "Ramen", "Tiramisu", "Spätzle", "Burrito",
      "Gnocchi", "Falafel", "Croissant", "Eintopf", "Waffel", "Risotto",
      "Pommes", "Käsekuchen",
    ]),
  WordCategory(
    id: "berufe", name: "Berufe",
    words: [
      "Arzt", "Lehrer", "Pilot", "Koch", "Gärtner", "Anwalt", "Friseur",
      "Maurer", "Tierarzt", "Astronaut", "Feuerwehrmann", "Bäcker",
      "Richter", "Schauspieler", "Klempner", "Architekt", "Förster",
      "Kellner", "Mechaniker", "Hebamme",
    ]),
  WordCategory(
    id: "getraenke", name: "Getränke",
    words: [
      "Cola", "Bier", "Espresso", "Limonade", "Wein", "Smoothie", "Tee",
      "Mojito", "Kakao", "Wasser", "Apfelschorle", "Whisky", "Eistee",
      "Sekt", "Latte", "Energydrink", "Gin Tonic", "Milch", "Spezi", "Glühwein",
    ]),
  WordCategory(
    id: "musik", name: "Musik",
    words: [
      "Klavier", "Gitarre", "Schlagzeug", "Oper", "Techno", "Geige",
      "Chor", "Rap", "Saxofon", "Jazz", "Trompete", "Reggae", "Flöte",
      "Mundharmonika", "Mikrofon", "Harfe", "Punk", "Cello", "Walzer", "Beat",
    ]),
]

let specials: [SpecialRole] = [
  SpecialRole(id: "saboteur", name: "Saboteur", desc: "Will als Imposter verdächtigt werden."),
  SpecialRole(id: "senior", name: "Senior", desc: "Begriff nur lückenhaft lesbar."),
  SpecialRole(id: "doppelagent", name: "Doppelagent", desc: "Bekommt komplett andere Wörter."),
]

// MARK: - App State

final class GameState: ObservableObject {
  @Published var screen: Screen = .menu
  @Published var players = 5
  @Published var names: [String] = []
  @Published var roles: [String: Bool] = ["saboteur": true, "senior": false, "doppelagent": false]
  @Published var category = "alltag"
  @Published var scores: [Int] = []
  @Published var roundNumber = 0
  @Published var roundCards: [RoundCard] = []
  @Published var revealIndex = 0
  @Published var theNum = 0
  @Published var rolesShown = false
  @Published var savedGame: GameSave?
  @Published var winnerShown = false
  @Published var showWinnerOverlay = false

  let win = 14
  private let persistence: GamePersistence
  private let roundBuilder: RoundBuilder

  enum Screen {
    case menu
    case rules
    case setup
    case reveal
    case score
  }

  init(
    persistence: GamePersistence = GamePersistence(),
    roundBuilder: RoundBuilder = RoundBuilder()
  ) {
    self.persistence = persistence
    self.roundBuilder = roundBuilder
    loadSavedPreview()
  }

  // MARK: Winner logic

  var winnerIndex: Int? {
    guard let max = scores.max(), max >= win else { return nil }
    return scores.firstIndex(of: max)
  }

  func checkWinner() {
    guard winnerIndex != nil, !winnerShown else { return }
    winnerShown = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
      withAnimation(.easeIn(duration: 0.25)) { self?.showWinnerOverlay = true }
    }
  }

  // MARK: Player helpers

  func maxSpecial() -> Int { min(3, max(0, players - 3)) }
  func chosenCount() -> Int { roles.values.filter { $0 }.count }

  func playerName(_ index: Int) -> String {
    guard index < names.count else { return "Spieler \(index + 1)" }
    let t = names[index].trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? "Spieler \(index + 1)" : t
  }

  // MARK: Actions

  func changePlayers(_ value: Int) {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
      players = min(8, max(3, players + value))

      while chosenCount() > maxSpecial() {
        guard
          let selectedRole = specials.first(where: {
            roles[$0.id] == true
          })
        else {
          break
        }
        roles[selectedRole.id] = false
      }

      if names.count < players {
        names.append(
          contentsOf: Array(
            repeating: "",
            count: players - names.count
          )
        )
      }
    }
  }

  func startRoom() {
    if names.count < players {
      names.append(contentsOf: Array(repeating: "", count: players - names.count))
    }
    scores = Array(repeating: 0, count: players)
    roundNumber = 1
    winnerShown = false
    showWinnerOverlay = false
    buildRound()
    revealIndex = 0
    save()
    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
      screen = .reveal
    }
  }

  func nextRound() {
    roundNumber += 1
    winnerShown = false
    buildRound()
    revealIndex = 0
    rolesShown = false
    save()
    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
      screen = .reveal
    }
  }

  func openScore() {
    rolesShown = false
    save()
    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
      screen = .score
    }
    checkWinner()
  }

  func adjust(_ index: Int, by amount: Int) {
    guard scores.indices.contains(index) else { return }
    scores[index] = min(win, max(0, scores[index] + amount))
    save()
    checkWinner()
  }

  func setScore(_ index: Int, value: String) {
    guard scores.indices.contains(index) else { return }
    scores[index] = min(win, max(0, Int(value) ?? 0))
    save()
    checkWinner()
  }

  func endRoom() {
    persistence.delete()
    savedGame = nil
    showWinnerOverlay = false
    winnerShown = false
    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
      screen = .menu
    }
  }

  func save() {
    let game = GameSave(
      players: players,
      names: names,
      roles: roles,
      category: category,
      scores: scores,
      roundNumber: roundNumber,
      assign: roundCards,
      theNum: theNum
    )
    persistence.save(game)
    savedGame = game
  }

  func loadSavedPreview() {
    savedGame = persistence.load()
  }

  func resumeSession() {
    guard let game = savedGame else { return }
    players = game.players
    names = game.names
    roles = game.roles
    category = game.category
    scores = game.scores
    roundNumber = game.roundNumber
    roundCards = game.assign
    theNum = game.theNum
    rolesShown = false
    winnerShown = false
    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
      screen = .score
    }
  }

  // MARK: Round building

  private func buildRound() {
    guard
      let round = roundBuilder.build(
        playerCount: players,
        playerName: playerName,
        selectedRoles: roles,
        categoryID: category
      )
    else {
      return
    }

    roundCards = round.cards
    theNum = round.wordNumber
  }
}

// MARK: - Theme

extension Color {
  static let bgDark = Color(red: 0.051, green: 0.051, blue: 0.047)  // #0D0D0C
  static let bgLight = Color(red: 0.09, green: 0.09, blue: 0.085)
  static let cardBg = Color(red: 0.102, green: 0.102, blue: 0.094).opacity(0.92)  // #1A1A18
  static let iosAccent = Color(red: 0.784, green: 0.878, blue: 0.0)  // #C8E000 Gelbgrün
  static let iosPurple = Color(red: 0.482, green: 0.361, blue: 0.902)  // #7B5CE6 Violett
  static let iosPink = Color(red: 0.482, green: 0.361, blue: 0.902)  // Alias für iosPurple
  static let iosGreen = Color(red: 0.2, green: 0.85, blue: 0.45)
  static let iosYellow = Color(red: 0.784, green: 0.878, blue: 0.0)  // = iosAccent
  static let borderLine = Color.white.opacity(0.12)
}

func roleColor(_ role: PlayerRole) -> Color {
  switch role {
  case .imposter: return .iosAccent
  case .crew: return .iosGreen
  default: return .iosPurple
  }
}

struct PremiumButtonStyle: ButtonStyle {
  var variant: Variant = .primary
  enum Variant { case primary, secondary, outline }

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.body, design: .rounded).bold())
      .textCase(.uppercase)
      .foregroundColor(textColor)
      .padding(.vertical, 16)
      .padding(.horizontal, 24)
      .frame(maxWidth: .infinity)
      .background(bg(isPressed: configuration.isPressed))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(borderColor, lineWidth: 1.5)
      )
      .shadow(color: shadowColor(isPressed: configuration.isPressed), radius: 8, y: 4)
      .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
      .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
  }

  private var textColor: Color {
    variant == .primary ? Color(red: 0.051, green: 0.051, blue: 0.047) : .white
  }

  @ViewBuilder
  private func bg(isPressed: Bool) -> some View {
    switch variant {
    case .primary:
      Color.iosAccent.brightness(isPressed ? -0.08 : 0)
    case .secondary:
      LinearGradient(
        colors: [.iosPurple, Color(red: 0.36, green: 0.24, blue: 0.59)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      .brightness(isPressed ? -0.05 : 0)
    case .outline:
      Color.white.opacity(isPressed ? 0.08 : 0.04)
    }
  }

  private var borderColor: Color {
    variant == .outline ? Color.white.opacity(0.2) : .clear
  }

  private func shadowColor(isPressed: Bool) -> Color {
    if isPressed { return .clear }
    switch variant {
    case .primary: return Color.iosAccent.opacity(0.45)
    case .secondary: return Color.iosPurple.opacity(0.3)
    default: return Color.black.opacity(0.2)
    }
  }
}

// MARK: - Root View

struct ContentView: View {
  @StateObject private var game = GameState()

  var body: some View {
    ZStack {
      LinearGradient(colors: [.bgLight, .bgDark], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()

      BackgroundDecorations()

      ScrollView(showsIndicators: false) {
        VStack {
          switch game.screen {
          case .menu:
            MenuView()
              .transition(
                .asymmetric(
                  insertion: .move(edge: .trailing).combined(with: .opacity),
                  removal: .move(edge: .leading).combined(with: .opacity)))
          case .rules:
            RulesView()
              .transition(
                .asymmetric(
                  insertion: .move(edge: .trailing).combined(with: .opacity),
                  removal: .move(edge: .leading).combined(with: .opacity)))
          case .setup:
            SetupView()
              .transition(
                .asymmetric(
                  insertion: .move(edge: .trailing).combined(with: .opacity),
                  removal: .move(edge: .leading).combined(with: .opacity)))
          case .reveal:
            RevealView()
              .transition(
                .asymmetric(
                  insertion: .move(edge: .trailing).combined(with: .opacity),
                  removal: .move(edge: .leading).combined(with: .opacity)))
          case .score:
            ScoreView()
              .transition(
                .asymmetric(
                  insertion: .move(edge: .trailing).combined(with: .opacity),
                  removal: .move(edge: .leading).combined(with: .opacity)))
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 48)
        .frame(maxWidth: 500)
      }

      // Gewinner-Overlay — liegt über allem
      if game.showWinnerOverlay, let idx = game.winnerIndex {
        WinnerOverlayView(
          winnerName: game.playerName(idx),
          onClose: {
            withAnimation(.easeOut(duration: 0.3)) { game.showWinnerOverlay = false }
          },
          onEndRoom: {
            game.showWinnerOverlay = false
            game.endRoom()
          }
        )
        .ignoresSafeArea()
        .transition(.opacity.animation(.easeIn(duration: 0.25)))
        .zIndex(100)
      }
    }
    .foregroundColor(.white)
    .environmentObject(game)
  }
}

// MARK: - Background

struct FloatingBgBlob: View {
  let color: Color
  @State private var offset = CGSize(
    width: CGFloat.random(in: -50...50), height: CGFloat.random(in: -80...80))
  @State private var scale: CGFloat = CGFloat.random(in: 0.8...1.2)

  var body: some View {
    Circle().fill(color).frame(width: 200, height: 200)
      .scaleEffect(scale).blur(radius: 50).offset(offset)
      .onAppear {
        withAnimation(
          .easeInOut(duration: Double.random(in: 6...10)).repeatForever(autoreverses: true)
        ) {
          offset = CGSize(
            width: CGFloat.random(in: -80...80), height: CGFloat.random(in: -120...120))
          scale = CGFloat.random(in: 0.8...1.3)
        }
      }
  }
}

struct BackgroundDecorations: View {
  var body: some View {
    ZStack {
      FloatingBgBlob(color: Color.iosPurple.opacity(0.10)).offset(x: -120, y: -280)
      FloatingBgBlob(color: Color.iosAccent.opacity(0.07)).offset(x: 120, y: 220)
      FloatingBgBlob(color: Color.iosPurple.opacity(0.05)).offset(x: 0, y: -50)

      Text("BLUFFEN")
        .font(.system(size: 72, weight: .black, design: .rounded))
        .foregroundColor(Color.white.opacity(0.02))
        .rotationEffect(.degrees(-20)).offset(x: 110, y: -300)
      Text("RATEN")
        .font(.system(size: 70, weight: .black, design: .rounded))
        .foregroundColor(Color.white.opacity(0.02))
        .rotationEffect(.degrees(16)).offset(x: -120, y: 280)
    }
    .ignoresSafeArea()
  }
}

// MARK: - Shared UI

struct TopBar: View {
  var title: String
  var roundText: String? = nil
  var backAction: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: backAction) {
        Image(systemName: "chevron.left")
          .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
          .frame(width: 38, height: 38).background(Color.cardBg).cornerRadius(12)
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderLine, lineWidth: 1.5))
      }.buttonStyle(.plain)

      Text(title).font(.system(.title3, design: .rounded).bold()).foregroundColor(.white)
      Spacer()

      if let rt = roundText {
        Text(rt).font(.system(.subheadline, design: .rounded).bold())
          .foregroundColor(.white.opacity(0.4))
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Color.white.opacity(0.06)).cornerRadius(8)
      }
    }
    .padding(.bottom, 20)
  }
}

struct Block<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.system(.footnote, design: .rounded).bold())
        .foregroundColor(.white.opacity(0.5)).textCase(.uppercase).tracking(1.2)
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18).background(Color.cardBg).cornerRadius(20)
    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderLine, lineWidth: 1.5))
    .padding(.bottom, 12)
  }
}

struct LabelTitle: View {
  let text: String
  var body: some View {
    Text(text).font(.system(.footnote, design: .rounded).bold())
      .textCase(.uppercase).foregroundColor(.white.opacity(0.4)).tracking(1.0)
      .padding(.top, 24).padding(.bottom, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Menu

struct MenuView: View {
  @EnvironmentObject var game: GameState

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 12) {
        Text("Pass & Play · 3–8 Spieler")
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .tracking(1.5).textCase(.uppercase).foregroundColor(.white)
          .padding(.horizontal, 14).padding(.vertical, 6)
          .background(Color.iosPurple).clipShape(Capsule())
          .padding(.bottom, 4)

        HStack(spacing: 2) {
          Text("IMP").foregroundColor(.white)
          Text("O").foregroundColor(.iosAccent)
          Text("STER").foregroundColor(.white)
        }
        .font(.system(size: 64, weight: .black, design: .rounded))
        .minimumScaleFactor(0.6).lineLimit(1)

        HStack(spacing: 4) {
          Text("Bluffen · Raten ·")
          Text("Entlarven").foregroundColor(.iosAccent)
        }
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .textCase(.uppercase).tracking(0.5)

        Text(
          "Alle kennen den Begriff — nur einer nicht. Gib clevere Hinweise und entlarve, wer in Wahrheit nichts weiß."
        )
        .font(.system(.body, design: .rounded))
        .foregroundColor(.white.opacity(0.6))
        .multilineTextAlignment(.center).lineSpacing(4)
        .padding(.horizontal, 12).padding(.top, 4)
      }
      .padding(.top, 24)

      HStack(spacing: 10) {
        FactView(
          icon: "text.quote", value: "1", label: "Begriff / Runde",
          gradient: LinearGradient(
            colors: [.iosAccent, .iosPurple], startPoint: .top, endPoint: .bottom))
        FactView(
          icon: "person.2.badge.gearshape.fill", value: "4", label: "Sonderrollen",
          gradient: LinearGradient(
            colors: [.iosPurple, Color(red: 0.36, green: 0.24, blue: 0.59)], startPoint: .top,
            endPoint: .bottom))
        FactView(
          icon: "trophy.fill", value: "14", label: "Punkte zum Sieg",
          gradient: LinearGradient(
            colors: [.iosAccent, Color(red: 0.6, green: 0.7, blue: 0)], startPoint: .top,
            endPoint: .bottom))
      }
      .padding(.top, 28)

      if let save = game.savedGame, save.roundNumber > 0 {
        VStack(alignment: .leading, spacing: 10) {
          Text("Fortlaufende Runde:")
            .font(.system(.footnote, design: .rounded).bold())
            .foregroundColor(.white.opacity(0.5)).textCase(.uppercase).tracking(1.0)
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text("Runde \(save.roundNumber)")
                .font(.system(.headline, design: .rounded).bold()).foregroundColor(.white)
              Text("\(save.players) Spieler · Kategorie: \(save.category.capitalized)")
                .font(.system(.subheadline, design: .rounded)).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Button("Fortsetzen") { game.resumeSession() }
              .buttonStyle(PremiumButtonStyle(variant: .secondary)).frame(width: 130)
          }
        }
        .padding(16).background(Color.cardBg).cornerRadius(20)
        .overlay(
          RoundedRectangle(cornerRadius: 20).stroke(Color.iosAccent.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.top, 24)
      }

      VStack(spacing: 12) {
        Button("Neues Spiel") {
          withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { game.screen = .setup }
        }
        .buttonStyle(PremiumButtonStyle(variant: .primary))

        Button {
          withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { game.screen = .rules }
        } label: {
          Label("Spielregeln", systemImage: "book.closed.fill")
        }
        .buttonStyle(PremiumButtonStyle(variant: .outline))
      }
      .padding(.top, 24)
    }
  }
}

struct FactView: View {
  let icon: String
  let value: String
  let label: String
  let gradient: LinearGradient

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        Circle().fill(gradient.opacity(0.15)).frame(width: 40, height: 40)
        Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(gradient)
      }
      Text(value).font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(.white)
      Text(label).font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center).lineLimit(2)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 16).padding(.horizontal, 6)
    .background(Color.cardBg).cornerRadius(20)
    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderLine, lineWidth: 1.5))
  }
}

// MARK: - Rules

struct RulesView: View {
  @EnvironmentObject var game: GameState

  var body: some View {
    VStack(spacing: 0) {
      TopBar(title: "Spielregeln") {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { game.screen = .menu }
      }

      Block(title: "Worum geht's?") {
        Text(
          "Alle bekommen denselben Begriff — nur der Imposter nicht. Mit cleveren Hinweisen müsst ihr ihn enttarnen, bevor er das Wort errät. Doch zwischen euch lauern noch fiese Sonderrollen …"
        )
        .font(.system(.body, design: .rounded)).foregroundColor(.white.opacity(0.8)).lineSpacing(4)
      }

      Block(title: "So läuft eine Runde") {
        VStack(alignment: .leading, spacing: 14) {
          RuleStep(
            number: 1, text: "Karten verteilen — jeder sieht heimlich seine Rolle & seinen Begriff."
          )
          RuleStep(
            number: 2, text: "Eine Zahl von 1–20 wird gezogen: das ist der Begriff der Runde.")
          RuleStep(
            number: 3,
            text:
              "Reihum gibt jeder einen Hinweis zu seinem Begriff. Sobald alle einmal dran waren, ist eine Runde vorbei (2–3 Runden gesamt)."
          )
          RuleStep(number: 4, text: "Diskutieren & abstimmen: Wer ist der Imposter?")
          RuleStep(
            number: 5,
            text:
              "Wenn alle Hinweis-Runden gespielt wurden: Die Person, die das Handy hält, öffnet die Auswertung und trägt die Punkte für alle ein. Sieg bei 14 Punkten."
          )
        }
      }

      Block(title: "So spielt ihr's digital") {
        Text(
          "Ein Spielzimmer merkt sich eure Namen und Punkte rundenübergreifend. Ihr spielt am selben Handy (Pass & Play): Karten gehen reihum, jeder deckt seine eigene heimlich auf. Sobald alle Hinweis-Runden gespielt wurden, öffnet die Person, die das Handy gerade hält, mit dem Button „Fertig — zur Auswertung\" die Punkteverteilung und tippt die Punkte für alle ein."
        )
        .font(.system(.body, design: .rounded)).foregroundColor(.white.opacity(0.8)).lineSpacing(4)
      }

      Block(title: "Die Rollen") {
        VStack(alignment: .leading, spacing: 14) {
          RoleRow(
            title: "Imposter",
            desc: "Kennt den Begriff nicht. Muss improvisieren und ihn erraten, ohne aufzufliegen.",
            color: .iosAccent)
          RoleRow(
            title: "Saboteur",
            desc: "Kennt den Begriff — will aber absichtlich als Imposter verdächtigt werden.",
            color: .iosPurple)
          RoleRow(
            title: "Senior",
            desc: "Sieht den Begriff nur lückenhaft. Darf sich nichts anmerken lassen.",
            color: .iosPurple)
          RoleRow(
            title: "Doppelagent",
            desc: "Bekommt einen komplett anderen Begriff — und weiß selbst nicht, wo er steht.",
            color: .iosPurple)
          RoleRow(
            title: "Crew", desc: "Kennt den echten Begriff und muss den Imposter enttarnen.",
            color: .iosGreen)
        }
      }
    }
  }
}

struct RuleStep: View {
  let number: Int
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(number)").font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundColor(Color(red: 0.051, green: 0.051, blue: 0.047))
        .frame(width: 24, height: 24)
        .background(Color.iosAccent).cornerRadius(6)
      Text(text).font(.system(.body, design: .rounded))
        .foregroundColor(.white.opacity(0.8)).lineSpacing(3)
    }
  }
}

struct RoleRow: View {
  let title: String
  let desc: String
  let color: Color

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text(title).font(.system(.subheadline, design: .rounded).bold())
        .textCase(.uppercase).foregroundColor(color).frame(width: 100, alignment: .leading)
      Text(desc).font(.system(.footnote, design: .rounded))
        .foregroundColor(.white.opacity(0.65)).lineSpacing(3)
    }
  }
}

// MARK: - Setup

struct SetupView: View {
  @EnvironmentObject var game: GameState

  var body: some View {
    VStack(spacing: 0) {
      TopBar(title: "Neues Spiel") {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { game.screen = .menu }
      }

      LabelTitle(text: "Spieleranzahl")

      HStack {
        Button {
          game.changePlayers(-1)
        } label: {
          Image(systemName: "minus").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            .frame(width: 48, height: 48).background(Color.white.opacity(0.08)).clipShape(Circle())
            .overlay(Circle().stroke(Color.borderLine, lineWidth: 1.5))
        }
        .disabled(game.players <= 3).opacity(game.players <= 3 ? 0.3 : 1)

        Spacer()
        VStack(spacing: 2) {
          Text("\(game.players)").font(.system(size: 48, weight: .black, design: .rounded))
            .foregroundColor(.white)
          Text("Spieler").font(.system(.caption, design: .rounded).bold())
            .foregroundColor(.white.opacity(0.5)).textCase(.uppercase)
        }
        Spacer()

        Button {
          game.changePlayers(1)
        } label: {
          Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            .frame(width: 48, height: 48).background(Color.white.opacity(0.08)).clipShape(Circle())
            .overlay(Circle().stroke(Color.borderLine, lineWidth: 1.5))
        }
        .disabled(game.players >= 8).opacity(game.players >= 8 ? 0.3 : 1)
      }
      .padding(.vertical, 14).padding(.horizontal, 20).background(Color.cardBg).cornerRadius(24)
      .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.borderLine, lineWidth: 1.5))

      Text(
        game.maxSpecial() == 0
          ? "Bei \(game.players) Spielern: nur Imposter, keine Sonderrollen."
          : "Bei \(game.players) Spielern: bis zu \(game.maxSpecial()) Sonderrolle\(game.maxSpecial() > 1 ? "n" : "") spielbar."
      )
      .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(
        .white.opacity(0.8)
      )
      .padding(14).frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.iosPurple.opacity(0.12)).cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16).stroke(Color.iosPurple.opacity(0.35), lineWidth: 1.5)
      )
      .padding(.top, 12)

      LabelTitle(text: "Spielernamen")

      VStack(spacing: 10) {
        ForEach(0..<game.players, id: \.self) { i in
          HStack(spacing: 12) {
            ZStack {
              Circle().fill(Color.iosPurple).frame(width: 28, height: 28)
              Text("\(i + 1)").font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            }
            TextField(
              "Spieler \(i + 1)",
              text: Binding(
                get: { i < game.names.count ? game.names[i] : "" },
                set: { v in
                  while game.names.count <= i { game.names.append("") }
                  game.names[i] = String(v.prefix(16))
                }
              )
            )
            .font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(.white)
            .textInputAutocapitalization(.words).disableAutocorrection(true)
          }
          .padding(.vertical, 12).padding(.horizontal, 16).background(Color.cardBg).cornerRadius(16)
          .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderLine, lineWidth: 1.5))
        }
      }

      LabelTitle(text: "Sonderrollen (\(game.chosenCount()) / \(game.maxSpecial()))")

      VStack(spacing: 10) {
        ForEach(specials) { special in
          let on = game.roles[special.id] == true
          let blocked = !on && game.chosenCount() >= game.maxSpecial()
          Button {
            if !blocked {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                game.roles[special.id] = !(game.roles[special.id] ?? false)
              }
            }
          } label: {
            HStack(spacing: 16) {
              VStack(alignment: .leading, spacing: 4) {
                Text(special.name).font(.system(.body, design: .rounded).bold())
                  .foregroundColor(on ? .white : .white.opacity(0.8))
                Text(special.desc).font(.system(.caption, design: .rounded))
                  .foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.leading)
              }
              Spacer()
              CustomToggle(isOn: on)
            }
            .padding(16)
            .background(on ? Color.iosPurple.opacity(0.15) : Color.cardBg).cornerRadius(18)
            .overlay(
              RoundedRectangle(cornerRadius: 18)
                .stroke(on ? Color.iosPurple.opacity(0.6) : Color.borderLine, lineWidth: 1.5)
            )
            .opacity(blocked ? 0.4 : 1.0)
          }
          .buttonStyle(.plain).disabled(blocked && !on)
        }
      }

      LabelTitle(text: "Kategorie")

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(categories) { cat in
            let sel = game.category == cat.id
            Button {
              withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                game.category = cat.id
              }
            } label: {
              VStack(alignment: .leading, spacing: 12) {
                HStack {
                  Image(systemName: categoryIcon(for: cat.id))
                    .font(.system(size: 20)).foregroundColor(.white)
                  Spacer()
                  if sel {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.white).font(
                      .system(size: 18))
                  }
                }
                Spacer()
                Text(cat.name).font(.system(.body, design: .rounded).bold()).foregroundColor(.white)
                Text("\(cat.words.count) Begriffe").font(.system(.caption, design: .rounded))
                  .foregroundColor(.white.opacity(0.8))
              }
              .padding(16).frame(width: 130, height: 120)
              .background(categoryGradient(for: cat.id).opacity(sel ? 1.0 : 0.2)).cornerRadius(20)
              .overlay(
                RoundedRectangle(cornerRadius: 20)
                  .stroke(sel ? Color.white.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1.5)
              )
            }
            .buttonStyle(.plain)
            .scaleEffect(sel ? 1.04 : 0.96)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: sel)
          }
        }
        .padding(.horizontal, 4)
      }

      Button("Spielzimmer starten") { game.startRoom() }
        .buttonStyle(PremiumButtonStyle(variant: .primary)).padding(.top, 32)
    }
  }

  private func categoryIcon(for id: String) -> String {
    switch id {
    case "alltag": return "house.fill"
    case "tiere": return "pawprint.fill"
    case "essen": return "fork.knife"
    case "berufe": return "briefcase.fill"
    case "getraenke": return "cup.and.saucer.fill"
    case "musik": return "music.note"
    default: return "star.fill"
    }
  }

  private func categoryGradient(for id: String) -> LinearGradient {
    switch id {
    case "alltag":
      return LinearGradient(
        colors: [Color(red: 0.2, green: 0.8, blue: 0.9), Color(red: 0.4, green: 0.3, blue: 0.9)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    case "tiere":
      return LinearGradient(
        colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
    case "essen":
      return LinearGradient(
        colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    case "berufe":
      return LinearGradient(
        colors: [.blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
    case "getraenke":
      return LinearGradient(
        colors: [.iosPurple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
    case "musik":
      return LinearGradient(
        colors: [.iosPurple, Color(red: 0.1, green: 0.1, blue: 0.6)], startPoint: .topLeading,
        endPoint: .bottomTrailing)
    default:
      return LinearGradient(
        colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }
}

struct CustomToggle: View {
  var isOn: Bool
  var body: some View {
    ZStack(alignment: isOn ? .trailing : .leading) {
      Capsule().fill(isOn ? Color.iosPurple : Color.white.opacity(0.1)).frame(width: 48, height: 28)
      Circle().fill(.white).frame(width: 22, height: 22).padding(3)
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
  }
}

// MARK: - Reveal

struct RevealView: View {
  @EnvironmentObject var game: GameState
  @State private var cardOpen = false

  var body: some View {
    VStack(spacing: 0) {
      TopBar(title: "Karten aufdecken", roundText: "Runde \(game.roundNumber)") {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { game.screen = .score }
      }
      if game.revealIndex >= game.roundCards.count {
        RevealDoneView()
      } else {
        let card = game.roundCards[game.revealIndex]
        VStack(spacing: 20) {
          HStack(spacing: 6) {
            ForEach(0..<game.roundCards.count, id: \.self) { i in
              Capsule()
                .fill(
                  i == game.revealIndex
                    ? Color.iosAccent
                    : (i < game.revealIndex ? Color.iosGreen : Color.white.opacity(0.15))
                )
                .frame(height: 6).frame(maxWidth: .infinity)
                .animation(.spring(), value: game.revealIndex)
            }
          }.padding(.bottom, 12)

          Text("Gib das Handy an").font(.system(.headline, design: .rounded)).foregroundColor(
            .white.opacity(0.5))
          Text(card.name).font(.system(size: 42, weight: .black, design: .rounded))
            .textCase(.uppercase).foregroundColor(.iosAccent).multilineTextAlignment(.center)
            .padding(.vertical, 8).shadow(color: Color.iosAccent.opacity(0.3), radius: 10, y: 4)
          Text("Niemand sonst schaut mit, ja?").font(.system(.footnote, design: .rounded))
            .foregroundColor(.white.opacity(0.4)).padding(.bottom, 12)

          FlippingCardView(card: card, number: game.theNum, isFlipped: $cardOpen)
            .frame(height: 250).padding(.horizontal, 8)
          Spacer().frame(height: 16)

          if cardOpen {
            Button("Gesehen — weiter") {
              withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                cardOpen = false
                game.revealIndex += 1
              }
            }
            .buttonStyle(PremiumButtonStyle(variant: .primary))
            .transition(.move(edge: .bottom).combined(with: .opacity))
          } else {
            Spacer().frame(height: 54)
          }
        }
        .padding(.top, 12)
      }
    }
  }
}

struct FlippingCardView: View {
  let card: RoundCard
  let number: Int
  @Binding var isFlipped: Bool

  var body: some View {
    ZStack {
      SecretCard(card: card, number: number).rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        .opacity(isFlipped ? 1 : 0)
      CoverCard(initial: String(card.name.prefix(1)).uppercased()).opacity(isFlipped ? 0 : 1)
    }
    .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (0, 1, 0), perspective: 0.5)
    .onTapGesture {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
        isFlipped.toggle()
      }
    }
  }
}

struct CoverCard: View {
  let initial: String
  var body: some View {
    VStack(spacing: 16) {
      Spacer()
      ZStack {
        Circle().stroke(
          LinearGradient(
            colors: [.iosPurple, .iosAccent], startPoint: .topLeading, endPoint: .bottomTrailing),
          style: StrokeStyle(lineWidth: 2, dash: [8, 4])
        ).frame(width: 80, height: 80)
        Text(initial).font(.system(size: 32, weight: .black, design: .rounded))
          .foregroundStyle(
            LinearGradient(
              colors: [.iosPurple, .iosAccent], startPoint: .topLeading, endPoint: .bottomTrailing))
      }
      VStack(spacing: 6) {
        Text("Deine Geheimkarte").font(.system(.headline, design: .rounded).bold()).foregroundColor(
          .white)
        Text("Antippen zum Umdrehen").font(.system(.caption, design: .rounded).bold())
          .foregroundColor(.white.opacity(0.5)).textCase(.uppercase).tracking(1.0)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.cardBg))
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [.iosPurple.opacity(0.4), .iosAccent.opacity(0.3)], startPoint: .topLeading,
            endPoint: .bottomTrailing), lineWidth: 2)
    )
    .shadow(color: Color.iosPurple.opacity(0.2), radius: 15, x: 0, y: 10)
  }
}

struct SecretCard: View {
  let card: RoundCard
  let number: Int
  var body: some View {
    ZStack {
      VStack(spacing: 20) {
        Spacer()
        VStack(spacing: 6) {
          Text(card.display)
            .font(.system(size: 40, weight: .black, design: .rounded))
            .foregroundColor(card.masked ? .iosPurple : .white)
            .textCase(.uppercase).minimumScaleFactor(0.5).lineLimit(2)
            .multilineTextAlignment(.center)
            .shadow(color: roleColor(card.role).opacity(0.3), radius: 8, x: 0, y: 4)
          Text(card.sub).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(
            .white.opacity(0.6))
        }
        if !card.secret.isEmpty {
          Text(card.secret).font(.system(.subheadline, design: .rounded).bold())
            .foregroundStyle(
              LinearGradient(
                colors: [.iosAccent, Color(red: 0.6, green: 0.7, blue: 0)], startPoint: .leading,
                endPoint: .trailing)
            )
            .multilineTextAlignment(.center).padding(.horizontal, 24).padding(.vertical, 8)
            .background(Color.white.opacity(0.06)).cornerRadius(12)
        }
        Spacer()
      }.padding(24)

      VStack {
        HStack(alignment: .center) {
          HStack(spacing: 4) {
            Image(systemName: "number").font(.system(size: 10, weight: .bold)).foregroundColor(
              .white.opacity(0.7))
            Text("\(number)").font(.system(size: 14, weight: .black, design: .rounded))
          }
          .foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 6)
          .background(Color.white.opacity(0.12)).cornerRadius(10)
          Spacer()
          Text(card.role.label).font(.system(size: 12, weight: .black, design: .rounded))
            .textCase(.uppercase).foregroundColor(
              card.role == .imposter ? Color(red: 0.05, green: 0.05, blue: 0.04) : .white
            )
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(roleColor(card.role)).cornerRadius(10)
            .shadow(color: roleColor(card.role).opacity(0.4), radius: 6, y: 3)
        }
        Spacer()
      }.padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.cardBg))
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(
        roleColor(card.role).opacity(0.4), lineWidth: 2)
    )
    .shadow(color: roleColor(card.role).opacity(0.2), radius: 15, x: 0, y: 10)
  }
}

struct RevealDoneView: View {
  @EnvironmentObject var game: GameState
  var body: some View {
    VStack(spacing: 20) {
      ZStack {
        Circle().fill(Color.iosGreen.opacity(0.15)).frame(width: 80, height: 80)
        Image(systemName: "checkmark.seal.fill").font(.system(size: 40, weight: .bold))
          .foregroundColor(.iosGreen)
      }.padding(.bottom, 8)

      Text("Alle haben ihre Karte gesehen.").font(.system(.headline, design: .rounded))
        .foregroundColor(.white.opacity(0.6))

      HStack(spacing: 8) {
        Text("Begriff")
        Text("\(game.theNum)").foregroundColor(.iosAccent)
      }
      .font(.system(size: 42, weight: .black, design: .rounded)).textCase(.uppercase)

      Text(
        "Jetzt reihum Hinweise geben (2–3 Runden). Danach diskutieren, abstimmen — und dann die Auswertung öffnen."
      )
      .font(.system(.body, design: .rounded)).foregroundColor(.white.opacity(0.5))
      .multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 16).padding(.bottom, 16)

      Button("Fertig — zur Auswertung") { game.openScore() }
        .buttonStyle(PremiumButtonStyle(variant: .primary))
    }
    .padding(.top, 40)
  }
}

// MARK: - Score

struct ScoreView: View {
  @EnvironmentObject var game: GameState
  @State private var showEndAlert = false

  private var winnerIndex: Int? {
    guard let max = game.scores.max(), max >= game.win else { return nil }
    return game.scores.firstIndex(of: max)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TopBar(title: "Auswertung", roundText: "Runde \(game.roundNumber)") {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { game.screen = .menu }
      }

      Text("Spielzimmer · \(game.players) Spieler · Sieg bei \(game.win) Punkten")
        .font(.system(.footnote, design: .rounded).bold())
        .foregroundColor(.white.opacity(0.4)).padding(.bottom, 16)

      if let idx = winnerIndex {
        VStack(spacing: 8) {
          Text("🏆 SIEGER 🏆")
            .font(.system(.caption, design: .rounded).bold())
            .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.04)).tracking(2.0)
          Text(game.playerName(idx))
            .font(.system(.title2, design: .rounded).bold())
            .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.04))
          Text("hat gewonnen mit \(game.scores[idx]) Punkten!")
            .font(.system(.footnote, design: .rounded))
            .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.04).opacity(0.7))
        }
        .frame(maxWidth: .infinity).padding(20)
        .background(
          LinearGradient(
            colors: [Color.iosAccent.opacity(0.9), Color(red: 0.6, green: 0.7, blue: 0)],
            startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.iosAccent, lineWidth: 1.5))
        .shadow(color: Color.iosAccent.opacity(0.3), radius: 15, y: 5).padding(.bottom, 20)
      }

      Button(game.rolesShown ? "Rollen verbergen" : "Rollen dieser Runde aufdecken") {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { game.rolesShown.toggle() }
      }
      .buttonStyle(PremiumButtonStyle(variant: .outline)).padding(.bottom, 16)

      Text("Punkte eintippen oder mit −/+1/+3 vergeben:")
        .font(.system(.footnote, design: .rounded, weight: .medium))
        .foregroundColor(.white.opacity(0.4)).padding(.bottom, 12)

      VStack(spacing: 12) {
        ForEach(0..<game.players, id: \.self) { i in ScoreRow(index: i) }
      }

      VStack(spacing: 12) {
        Button("Nächste Runde") { game.nextRound() }.buttonStyle(
          PremiumButtonStyle(variant: .primary))
        Button("Spielzimmer beenden") { showEndAlert = true }.buttonStyle(
          PremiumButtonStyle(variant: .outline))
      }
      .padding(.top, 28)
    }
    .alert("Spielzimmer wirklich beenden?", isPresented: $showEndAlert) {
      Button("Abbrechen", role: .cancel) {}
      Button("Beenden", role: .destructive) { game.endRoom() }
    } message: {
      Text("Punkte gehen verloren.")
    }
  }
}

struct ScoreRow: View {
  @EnvironmentObject var game: GameState
  let index: Int

  var body: some View {
    let score = game.scores.indices.contains(index) ? game.scores[index] : 0
    let maxScore = game.scores.max() ?? 0
    let isLead = score == maxScore && maxScore > 0
    let card = game.roundCards.indices.contains(index) ? game.roundCards[index] : nil

    VStack(spacing: 12) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(game.playerName(index)).font(.system(.body, design: .rounded).bold())
              .foregroundColor(.white).lineLimit(1)
            if isLead {
              Image(systemName: "crown.fill").foregroundColor(.iosAccent).font(.system(size: 14))
            }
          }
          if game.rolesShown, let c = card {
            Text(roleText(c)).font(.system(size: 10, weight: .black, design: .rounded))
              .textCase(.uppercase).foregroundColor(roleColor(c.role))
          }
        }
        Spacer()

        HStack(spacing: 6) {
          Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
              game.adjust(index, by: -1)
            }
          } label: {
            Text("−").font(.system(size: 16, weight: .bold)).foregroundColor(.white.opacity(0.8))
              .frame(width: 32, height: 32).background(Color.white.opacity(0.08)).cornerRadius(8)
          }.buttonStyle(.plain)

          TextField(
            "",
            text: Binding(
              get: { "\(score)" },
              set: { game.setScore(index, value: $0) }
            )
          )
          .keyboardType(.numberPad).multilineTextAlignment(.center)
          .font(.system(size: 18, weight: .black, design: .rounded)).foregroundColor(.white)
          .frame(width: 40, height: 32).background(Color.white.opacity(0.12)).cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(
              isLead ? Color.iosAccent.opacity(0.5) : .clear, lineWidth: 1))

          Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
              game.adjust(index, by: 1)
            }
          } label: {
            Text("+1").font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(
              Color(red: 0.05, green: 0.05, blue: 0.04)
            )
            .frame(width: 36, height: 32).background(Color.iosAccent).cornerRadius(8)
          }.buttonStyle(.plain)

          Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
              game.adjust(index, by: 3)
            }
          } label: {
            Text("+3").font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(
              .white
            )
            .frame(width: 36, height: 32)
            .background(
              LinearGradient(
                colors: [.iosPurple, Color(red: 0.36, green: 0.24, blue: 0.59)], startPoint: .top,
                endPoint: .bottom)
            )
            .cornerRadius(8)
          }.buttonStyle(.plain)
        }
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
          Capsule()
            .fill(
              LinearGradient(
                colors: isLead
                  ? [.iosAccent, Color(red: 0.6, green: 0.7, blue: 0)]
                  : [.iosPurple, Color(red: 0.36, green: 0.24, blue: 0.59)],
                startPoint: .leading, endPoint: .trailing)
            )
            .frame(
              width: geo.size.width * CGFloat(min(1.0, Double(score) / Double(game.win))), height: 6
            )
        }
      }.frame(height: 6)
    }
    .padding(14).background(Color.cardBg).cornerRadius(18)
    .overlay(
      RoundedRectangle(cornerRadius: 18).stroke(
        isLead ? Color.iosAccent.opacity(0.4) : Color.borderLine, lineWidth: 1.5)
    )
    .shadow(color: isLead ? Color.iosAccent.opacity(0.08) : .clear, radius: 10, y: 5)
  }

  private func roleText(_ card: RoundCard) -> String {
    card.role == .imposter || card.role == .crew
      ? card.role.label : "\(card.role.label) · \(card.display)"
  }
}

// MARK: - Konfetti

private struct ConfettiParticleData: Identifiable {
  let id = UUID()
  let startX, startY, endX, endY: CGFloat
  let startRot, endRot: Double
  let color: Color
  let width, height: CGFloat
  let isCircle: Bool
  let delay, duration: Double
}

private func makeConfettiParticles() -> [ConfettiParticleData] {
  let w = UIScreen.main.bounds.width
  let h = UIScreen.main.bounds.height
  let colors: [Color] = [
    .iosAccent, .iosPurple, .white,
    Color(red: 0.9, green: 1.0, blue: 0.3),
    Color(red: 0.6, green: 0.45, blue: 0.95),
  ]
  return (0..<88).map { _ in
    let isCircle = Int.random(in: 0...2) == 0
    let pw = CGFloat.random(in: 6...14)
    return ConfettiParticleData(
      startX: CGFloat.random(in: 0...w),
      startY: CGFloat.random(in: -h * 0.35 ... -10),
      endX: CGFloat.random(in: -60...w + 60),
      endY: h + 70,
      startRot: Double.random(in: 0...360),
      endRot: Double.random(in: -720...720),
      color: colors.randomElement()!,
      width: pw,
      height: isCircle ? pw : CGFloat.random(in: 4...8),
      isCircle: isCircle,
      delay: Double.random(in: 0...1.5),
      duration: Double.random(in: 2.5...3.8)
    )
  }
}

private struct ConfettiPieceView: View {
  let data: ConfettiParticleData
  @State private var animate = false

  var body: some View {
    Group {
      if data.isCircle {
        Circle().fill(data.color).frame(width: data.width, height: data.width)
      } else {
        RoundedRectangle(cornerRadius: 1.5).fill(data.color).frame(
          width: data.width, height: data.height)
      }
    }
    .rotationEffect(.degrees(animate ? data.endRot : data.startRot))
    .position(x: animate ? data.endX : data.startX, y: animate ? data.endY : data.startY)
    .opacity(animate ? 0 : 1)
    .onAppear {
      withAnimation(.easeIn(duration: data.duration).delay(data.delay)) { animate = true }
    }
  }
}

private struct ConfettiView: View {
  @State private var particles = makeConfettiParticles()
  var body: some View {
    ZStack { ForEach(particles) { ConfettiPieceView(data: $0) } }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .allowsHitTesting(false)
  }
}

// MARK: - Winner Overlay

struct WinnerOverlayView: View {
  let winnerName: String
  let onClose: () -> Void
  let onEndRoom: () -> Void

  @State private var cardScale: CGFloat = 0.7
  @State private var cardOpacity: Double = 0
  @State private var trophyOffset: CGFloat = -40
  @State private var trophyOpacity: Double = 0

  var body: some View {
    ZStack {
      Color.black.opacity(0.85).ignoresSafeArea()
      ConfettiView().ignoresSafeArea()

      VStack(spacing: 20) {
        Text("🏆")
          .font(.system(size: 76))
          .offset(y: trophyOffset)
          .opacity(trophyOpacity)

        Text(winnerName)
          .font(.system(size: 44, weight: .black, design: .rounded))
          .textCase(.uppercase).foregroundColor(.iosAccent)
          .minimumScaleFactor(0.45).lineLimit(2).multilineTextAlignment(.center)
          .shadow(color: Color.iosAccent.opacity(0.5), radius: 16, y: 4)

        Text("gewinnt das Spiel!")
          .font(.system(.headline, design: .rounded).bold())
          .foregroundColor(.white.opacity(0.6)).textCase(.uppercase).tracking(0.5)

        VStack(spacing: 12) {
          Button("Ergebnis ansehen", action: onClose)
            .buttonStyle(PremiumButtonStyle(variant: .primary))
          Button("Spielzimmer beenden", action: onEndRoom)
            .buttonStyle(PremiumButtonStyle(variant: .outline))
        }
        .padding(.top, 8)
      }
      .padding(32)
      .background(Color(red: 0.12, green: 0.12, blue: 0.11))
      .cornerRadius(28)
      .overlay(
        RoundedRectangle(cornerRadius: 28).stroke(Color.iosAccent.opacity(0.45), lineWidth: 1.5)
      )
      .shadow(color: Color.iosAccent.opacity(0.3), radius: 32, y: 12)
      .padding(.horizontal, 24)
      .scaleEffect(cardScale).opacity(cardOpacity)
    }
    .onAppear {
      withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
        cardScale = 1.0
        cardOpacity = 1.0
      }
      withAnimation(.spring(response: 0.6, dampingFraction: 0.58).delay(0.4)) {
        trophyOffset = 0
        trophyOpacity = 1.0
      }
    }
  }
}

// MARK: - Preview

#Preview { ContentView() }
