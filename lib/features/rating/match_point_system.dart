import '../game/domain/game_result.dart';

enum MatchDifficulty { veryEasy, easy, medium, hard }

extension MatchDifficultyX on MatchDifficulty {
  String get label => switch (this) {
        MatchDifficulty.veryEasy => 'Very Easy',
        MatchDifficulty.easy => 'Easy',
        MatchDifficulty.medium => 'Medium',
        MatchDifficulty.hard => 'Hard',
      };

  /// Points earned for a win. Beating a strong opponent is worth much more
  /// (+7) than beating a weak one (+3).
  int get winPoints => switch (this) {
        MatchDifficulty.veryEasy => 3,
        MatchDifficulty.easy => 3,
        MatchDifficulty.medium => 5,
        MatchDifficulty.hard => 7,
      };

  /// Points lost for a defeat — mirror image of the win side: losing to a
  /// weak opponent hurts a lot (-5 / -7), losing to a strong one is almost
  /// expected (-3).
  int get lossPenalty => switch (this) {
        MatchDifficulty.veryEasy => 7,
        MatchDifficulty.easy => 5,
        MatchDifficulty.medium => 4,
        MatchDifficulty.hard => 3,
      };
}

class MatchPointSystem {
  MatchPointSystem._();

  static MatchDifficulty difficultyFor({
    required int playerRating,
    required int botRating,
  }) {
    final gap = botRating - playerRating;
    if (gap <= -250) return MatchDifficulty.veryEasy;
    if (gap <= -120) return MatchDifficulty.easy;
    if (gap >= 120) return MatchDifficulty.hard;
    return MatchDifficulty.medium;
  }

  static int ratingDelta({
    required MatchDifficulty difficulty,
    required GameResult result,
  }) => switch (result) {
        GameResult.win => difficulty.winPoints,
        GameResult.loss => -difficulty.lossPenalty,
        GameResult.draw => 0,
      };
}
