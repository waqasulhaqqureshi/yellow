import 'dart:math';

import '../bot/data/bot_generator.dart';
import '../bot/domain/bot_profile.dart';
import '../profile/domain/player_profile.dart';

/// Seam for v2 online play. v1 ships [OfflineBotSource]; a Supabase
/// implementation will plug in here without touching the UI.
/// See docs/SUPABASE_ONLINE_PLAN.md.
abstract class OpponentSource {
  Future<BotProfile> findOpponent({required PlayerProfile player});
}

/// Offline bot pool with a simulated arena search delay so pairing feels
/// like fair matchmaking (rating-aware bot, not an instant spawn).
class OfflineBotSource implements OpponentSource {
  OfflineBotSource({BotGenerator? generator, Random? random})
      : _generator = generator ?? BotGenerator(),
        _random = random ?? Random();

  final BotGenerator _generator;
  final Random _random;

  static const int minSearchMs = 2200;
  static const int maxSearchMs = 4200;

  @override
  Future<BotProfile> findOpponent({required PlayerProfile player}) async {
    final wait =
        minSearchMs + _random.nextInt(maxSearchMs - minSearchMs + 1);
    await Future.delayed(Duration(milliseconds: wait));
    return _generator.generate(
      playerRating: player.rating,
      winStreak: player.winStreak,
      lossStreak: player.lossStreak,
    );
  }
}
