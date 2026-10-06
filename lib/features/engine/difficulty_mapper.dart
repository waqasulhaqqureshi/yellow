import 'package:genetom_chess_engine/genetom_chess_engine.dart';

import '../bot/domain/bot_difficulty.dart';
import 'human_pace.dart';

/// Resolved engine behaviour for a bot tier.
///
/// Strength scales through time-boxed search depth, opening-book depth and
/// deliberate-error rates — never through unbounded thinking, so the UI can
/// never hang on a slow device.
class EngineSettings {
  /// Difficulty of the underlying genetom engine instance (rules + fallback).
  final Difficulty fallbackDifficulty;

  /// Chance of deliberately picking a sub-optimal (but sane) move.
  final double blunderRate;

  /// Max centipawns a deliberate blunder may drop (keeps errors human-like).
  final int blunderSlackCp;

  /// How many plies of the opening book are available.
  final int bookPly;

  /// Time-boxed search budget + depth cap.
  final int searchTimeMs;
  final int maxDepth;

  /// Human-like think-time window (runs concurrently with the search).
  final int minThinkMs;
  final int maxThinkMs;

  /// Pace inputs for the human timing model (time control + bot rating).
  final String paceTimeControl;
  final int paceRating;

  const EngineSettings({
    required this.fallbackDifficulty,
    required this.blunderRate,
    required this.blunderSlackCp,
    required this.bookPly,
    required this.searchTimeMs,
    required this.maxDepth,
    required this.minThinkMs,
    required this.maxThinkMs,
    this.paceTimeControl = 'Blitz',
    this.paceRating = 1200,
  });
}

class DifficultyMapper {
  DifficultyMapper._();

  /// Targets a strength between the player's current rating and the bot's
  /// rating so both the selected opponent and recent rating progress matter.
  static EngineSettings forMatch({
    required int playerRating,
    required int botRating,
    String timeControl = 'Blitz',
  }) {
    final targetRating = (playerRating * 0.35 + botRating * 0.65).round();
    final base = forTier(BotTiering.tierForRating(targetRating));
    final window = HumanPace.thinkWindowMs(
      timeControl: timeControl,
      rating: botRating,
    );
    return EngineSettings(
      fallbackDifficulty: base.fallbackDifficulty,
      blunderRate: base.blunderRate,
      blunderSlackCp: base.blunderSlackCp,
      bookPly: base.bookPly,
      searchTimeMs: base.searchTimeMs,
      maxDepth: base.maxDepth,
      minThinkMs: window.$1,
      maxThinkMs: window.$2,
      paceTimeControl: timeControl,
      paceRating: botRating,
    );
  }

  static EngineSettings forTier(BotTier tier) {
    switch (tier) {
      case BotTier.rookie:
        return const EngineSettings(
          fallbackDifficulty: Difficulty.tooEasy,
          blunderRate: 0.16,
          blunderSlackCp: 170,
          bookPly: 2,
          searchTimeMs: 350,
          maxDepth: 2,
          minThinkMs: 800,
          maxThinkMs: 2100,
        );
      case BotTier.club:
        return const EngineSettings(
          fallbackDifficulty: Difficulty.easy,
          blunderRate: 0.11,
          blunderSlackCp: 150,
          bookPly: 4,
          searchTimeMs: 650,
          maxDepth: 3,
          minThinkMs: 900,
          maxThinkMs: 2300,
        );
      case BotTier.expert:
        return const EngineSettings(
          fallbackDifficulty: Difficulty.medium,
          blunderRate: 0.065,
          blunderSlackCp: 125,
          bookPly: 6,
          searchTimeMs: 1200,
          maxDepth: 4,
          minThinkMs: 1000,
          maxThinkMs: 2400,
        );
      case BotTier.master:
        return const EngineSettings(
          fallbackDifficulty: Difficulty.hard,
          blunderRate: 0.035,
          blunderSlackCp: 100,
          bookPly: 8,
          searchTimeMs: 2000,
          maxDepth: 5,
          minThinkMs: 1000,
          maxThinkMs: 2600,
        );
      case BotTier.grandmaster:
        // Note: GM strength comes from our time-boxed search (depth 6) + full
        // book + zero blunders. The built-in `asian` depth is deliberately
        // NOT used as a fallback: it has no time control and can hang low-end
        // devices. See docs/ENGINE_NOTES.md.
        return const EngineSettings(
          fallbackDifficulty: Difficulty.hard,
          blunderRate: 0.015,
          blunderSlackCp: 75,
          bookPly: 10,
          searchTimeMs: 3000,
          maxDepth: 6,
          minThinkMs: 1100,
          maxThinkMs: 2800,
        );
    }
  }
}
