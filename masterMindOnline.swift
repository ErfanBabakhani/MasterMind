import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



struct CreateGameResponse: Codable {
    let game_id: String
}

struct GuessRequest: Codable {
    let game_id: String
    let guess: String
}

struct GuessResponse: Codable {
    let black: Int
    let white: Int
}

struct ErrorResponse: Codable {
    let error: String
}


class MastermindAPI {
    static let baseURL = "https://mastermind.darkube.app"
    
    private static func handleResponse<T: Decodable>(_ data: Data?, _ error: Error?, decode: T.Type) -> Result<T, Error> {
        if let error = error {
            return .failure(error)
        }
        guard let data = data else {
            return .failure(NSError(domain: "MastermindAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response"]))
        }
        
        do {
            return .success(try JSONDecoder().decode(T.self, from: data))
        } catch {
            if let apiError = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                return .failure(NSError(domain: "MastermindAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: apiError.error]))
            }
            return .failure(error)
        }
    }
    
    static func createGame(completion: @escaping (Result<CreateGameResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/game") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            completion(handleResponse(data, error, decode: CreateGameResponse.self))
        }.resume()
    }
    
    static func makeGuess(gameId: String, guess: String, completion: @escaping (Result<GuessResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/guess") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = GuessRequest(game_id: gameId, guess: guess)
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            completion(handleResponse(data, error, decode: GuessResponse.self))
        }.resume()
    }
    
    static func deleteGame(gameId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/game/\(gameId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
                completion(.success(()))
            } else if let data = data, let apiError = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                let err = NSError(domain: "MastermindAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: apiError.error])
                completion(.failure(err))
            } else {
                let err = NSError(domain: "MastermindAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete game"])
                completion(.failure(err))
            }
        }.resume()
    }
}


var activeGameId: String?

func printHelp() {
    print("""
Available commands:
  game              — Start a new game
  guess <1234>      — Make a guess in the active game
  delete <game_id>  — Delete a game
  help              — Show help message
  exit              — Exit the game
""")
}

func mainLoop() {
    print(" Welcome to Mastermind CLI!")
    print("Type 'help' for available commands.")
    
    while true {
        print("> ", terminator: "")
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !input.isEmpty else { continue }
        
        let parts = input.split(separator: " ")
        let command = parts.first?.lowercased() ?? ""
        
        switch command {
        case "help":
            printHelp()
            
        case "exit":
            print("Bye!")
            return
            
        case "game":
            let sema = DispatchSemaphore(value: 0)
            MastermindAPI.createGame { result in
                switch result {
                case .success(let game):
                    activeGameId = game.game_id
                    print("New game started with ID: \(game.game_id)")
                case .failure(let error):
                    print("Failed to create game: \(error.localizedDescription)")
                }
                sema.signal()
            }
            sema.wait()
            
        case "guess":
            guard parts.count > 1 else {
                print("Usage: guess <1234>")
                continue
            }
            guard let gameId = activeGameId else {
                print("No active game. Use 'game' first.")
                continue
            }
            let guess = String(parts[1])
            let sema = DispatchSemaphore(value: 0)
            MastermindAPI.makeGuess(gameId: gameId, guess: guess) { result in
                switch result {
                case .success(let response):
                    print("Result → ⚫️ Black: \(response.black), ⚪️ White: \(response.white)")
                case .failure(let error):
                    print("Guess error: \(error.localizedDescription)")
                }
                sema.signal()
            }
            sema.wait()
            
        case "delete":
            guard parts.count > 1 else {
                print("Usage: delete <game_id>")
                continue
            }
            let gameId = String(parts[1])
            let sema = DispatchSemaphore(value: 0)
            MastermindAPI.deleteGame(gameId: gameId) { result in
                switch result {
                case .success:
                    print("Game \(gameId) deleted")
                    if activeGameId == gameId {
                        activeGameId = nil
                    }
                case .failure(let error):
                    print("Delete error: \(error.localizedDescription)")
                }
                sema.signal()
            }
            sema.wait()
            
        default:
            print("Unknown command. Type 'help' for options.")
        }
    }
}

// اجرای برنامه
mainLoop()
