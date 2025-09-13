import Foundation

struct Game: Codable {
    let id: String
    let secret: [Int]
}

struct GameStartResponse: Codable {
    let game_id: String
}

struct GuessResponse: Codable {
    let black: Int
    let white: Int
}

struct ErrorResponse: Codable {
    let error: String
}

struct MessageResponse: Codable {
    let message: String
}

struct GameListResponse: Codable {
    let active: String?
    let games: [String]
}

final class GameStore {
    private var games: [String: Game] = [:]
    var activeGameId: String? = nil
    private let debug: Bool
    private let historyFile = "history.json"
    private(set) var history: [Game] = []

    init(debug: Bool) {
        self.debug = debug
        loadHistory()
    }

    private func loadHistory() {
        let url = URL(fileURLWithPath: historyFile)
        if let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode([Game].self, from: data) {
            history = loaded
        }
    }

    private func saveHistory() {
        let url = URL(fileURLWithPath: historyFile)
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: url)
        }
    }

    func createGame() -> Game {
        let id = UUID().uuidString
        let secret = (0..<4).map { _ in Int.random(in: 1...6) }
        let game = Game(id: id, secret: secret)
        games[id] = game
        activeGameId = id
        if debug {
            fputs("[DEBUG] secret(\(id)) = \(secret.map(String.init).joined())\n", stderr)
        }
        return game
    }

    func getActiveGame() -> Game? {
        guard let id = activeGameId else { return nil }
        return games[id]
    }

    func deleteGame(id: String) -> Bool {
        let removed = games.removeValue(forKey: id) != nil
        if activeGameId == id { activeGameId = nil }
        return removed
    }

    func archiveAndDeleteGame(_ game: Game) {
        history.append(game)
        saveHistory()
        deleteGame(id: game.id)
    }

    func listGames() -> GameListResponse {
        return GameListResponse(active: activeGameId, games: Array(games.keys))
    }

    func switchGame(id: String) -> Bool {
        guard games[id] != nil else { return false }
        activeGameId = id
        return true
    }
}


func evaluate(secret: [Int], guess: [Int]) -> (black: Int, white: Int) {
    var blacks = 0
    var secretRem: [Int] = []
    var guessRem:  [Int] = []

    for (s, g) in zip(secret, guess) {
        if s == g { blacks += 1 }
        else { secretRem.append(s); guessRem.append(g) }
    }

    var counts: [Int: Int] = [:]
    for s in secretRem { counts[s, default: 0] += 1 }

    var whites = 0
    for g in guessRem {
        if let c = counts[g], c > 0 {
            whites += 1
            counts[g] = c - 1
        }
    }
    return (blacks, whites)
}

func jsonEncode<T: Encodable>(_ value: T) -> String {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
    if let data = try? enc.encode(value), let s = String(data: data, encoding: .utf8) {
        return s
    }
    return "{\"error\":\"encoding failed\"}"
}

func parseGuessDigits(_ s: String) -> [Int]? {
    guard s.count == 4, s.allSatisfy({ "123456".contains($0) }) else { return nil }
    return s.compactMap { Int(String($0)) }
}

func printHelp() {
    print("""
    Commands:
      game
        Start a new game → JSON output with game_id
      guess <1234>
        Make a guess in the active game → JSON output with black/white
      delete <game_id>
        Delete a game → JSON output with message or error
      list
        List all active games and highlight the current active one
      switch <game_id>
        Switch to a different active game
      history
        Show archived games by their IDs
      help
        Show this help
      exit
        Exit

    Notes:
      • Each guess digit must be between 1..6, and exactly 4 digits long.
      • You can run the program with the --debug flag to see the secret code in STDERR.
    """)
}


let debugMode = CommandLine.arguments.contains("--debug")
let store = GameStore(debug: debugMode)

print("Mastermind (offline) — API-like terminal")
print("Type 'help' for commands. Type 'exit' to quit.")

while true {
    FileHandle.standardOutput.write(Data("\n> ".utf8))
    guard let line = readLine() else { break }
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { continue }

    if trimmed.lowercased() == "exit" { break }
    if trimmed.lowercased() == "help" {
        printHelp()
        continue
    }

    if trimmed.lowercased() == "game" {
        let game = store.createGame()
        print(jsonEncode(GameStartResponse(game_id: game.id)))
        continue
    }

    if trimmed.lowercased().hasPrefix("guess ") {
        let comps = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard comps.count == 2 else {
            print(jsonEncode(ErrorResponse(error: "Usage: guess <4 digits between 1..6>")))
            continue
        }
        guard let guess = parseGuessDigits(String(comps[1])) else {
            print(jsonEncode(ErrorResponse(error: "Guess must be 4 digits, each in 1..6")))
            continue
        }
        guard let game = store.getActiveGame() else {
            print(jsonEncode(ErrorResponse(error: "No active game. Create one with 'game'.")))
            continue
        }
        let (b, w) = evaluate(secret: game.secret, guess: guess)
        print(jsonEncode(GuessResponse(black: b, white: w)))

        if b == 4 {
            print("🎉 Congratulations! You guessed the secret code for game \(game.id)!")
            store.archiveAndDeleteGame(game)
        }
        continue
    }

    if trimmed.lowercased().hasPrefix("delete ") {
        let comps = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard comps.count == 2 else {
            print(jsonEncode(ErrorResponse(error: "Usage: delete <game_id>")))
            continue
        }
        let gid = String(comps[1])
        if store.deleteGame(id: gid) {
            print(jsonEncode(MessageResponse(message: "Game deleted")))
        } else {
            print(jsonEncode(ErrorResponse(error: "Game not found")))
        }
        continue
    }

    if trimmed.lowercased() == "list" {
        let resp = store.listGames()
        print(jsonEncode(resp))
        continue
    }

    if trimmed.lowercased().hasPrefix("switch ") {
        let comps = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard comps.count == 2 else {
            print(jsonEncode(ErrorResponse(error: "Usage: switch <game_id>")))
            continue
        }
        let gid = String(comps[1])
        if store.switchGame(id: gid) {
            print(jsonEncode(MessageResponse(message: "Switched to game \(gid)")))
        } else {
            print(jsonEncode(ErrorResponse(error: "Game not found")))
        }
        continue
    }

    if trimmed.lowercased() == "history" {
        let ids = store.history.map { $0.id }
        print(jsonEncode(["history": ids]))
        continue
    }

    print(jsonEncode(ErrorResponse(error: "Unknown command. Type 'help'.")))
}
