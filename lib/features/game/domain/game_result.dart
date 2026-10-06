/// Result of a finished game from the human player's perspective.
enum GameResult { win, loss, draw }

extension GameResultX on GameResult {
  String get label {
    switch (this) {
      case GameResult.win:
        return 'Victory';
      case GameResult.loss:
        return 'Defeat';
      case GameResult.draw:
        return 'Draw';
    }
  }

  String get short {
    switch (this) {
      case GameResult.win:
        return 'W';
      case GameResult.loss:
        return 'L';
      case GameResult.draw:
        return 'D';
    }
  }
}
