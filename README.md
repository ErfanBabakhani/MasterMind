# Mastermind (Offline) — Terminal Game

A simple **Mastermind** game implemented in Swift that runs entirely in the terminal. The game allows you to play offline with an API-like command interface and supports multiple concurrent games, game switching, and guess history tracking.

## Features

- Start multiple games and switch between them
- Make guesses and receive feedback (black & white pegs)
- Archive completed games <wined games>
- Debug mode to reveal secret codes
- JSON output for all commands for easy parsing

## Commands

Type `help` in the game for a detailed command list. Main commands include:

- `game` — Start a new game  
- `guess <1234>` — Make a guess in the active game  
- `delete <game_id>` — Delete a game  
- `list` — List all active games and highlight the current one  
- `switch <game_id>` — Switch to a different active game  
- `history` — List all archived games by their IDs  
- `history <game_id>` — Show the guess trace for a specific game  
- `help` — Show help message  
- `exit` — Exit the game  

> Notes:  



# Master Mind Online 🎮

A simple online implementation of the classic **Mastermind** game (CLI).  
This project uses the [Mastermind API](https://mastermind.darkube.app) to create games, submit guesses, and delete games.

---

## 📖 About the Game
Mastermind is a logic game where:

- The server selects a secret 4-digit code.
- You try to guess the code by submitting guesses.
- After each guess, the server returns two values:
  - ⚫️ **Black** → number of digits correct in the correct position  
  - ⚪️ **White** → number of digits correct but in the wrong position  

The game continues until you guess the entire code correctly.

---

## ▶️ Running the Program
Run the project using **Swift**:

```bash
swift run

## 📝 Available commands:
  game              — Start a new game
  guess <1234>      — Make a guess in the active game
  delete <game_id>  — Delete a game
  help              — Show help message
  exit              — Exit the game

> - Each guess must be **exactly 4 digits**, with values between 1..6.  
> - Run the program with `--debug` to see the secret code in STDERR.
