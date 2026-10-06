import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bot/data/bot_generator.dart';
import '../bot/domain/bot_profile.dart';
import '../profile/domain/player_profile.dart';
import '../rating/elo_service.dart';
import 'opponent_source.dart';

enum SearchPhase { idle, searching, found }

/// Drives the "Find Opponent" flow: searching state, elapsed timer, tips,
/// found bot + ELO preview.
class MatchmakingController extends ChangeNotifier {
  MatchmakingController({OpponentSource? source})
      : _source = source ?? OfflineBotSource();

  final OpponentSource _source;

  SearchPhase _phase = SearchPhase.idle;
  SearchPhase get phase => _phase;

  BotProfile? _bot;
  BotProfile? get bot => _bot;

  EloPreview? _preview;
  EloPreview? get preview => _preview;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  String get tip => tips[(_elapsed.inSeconds ~/ 3) % tips.length];

  Timer? _ticker;
  bool _cancelled = false;
  bool _disposed = false;

  static const List<String> tips = [
    'Control the centre with pawns and knights.',
    'Castle early to keep your king safe.',
    'Knights love outposts — bishops love open diagonals.',
    "Don't move the same piece twice in the opening.",
    'Look for checks, captures and threats every move.',
    'Trade pieces when winning; avoid trades when losing.',
    'Passed pawns must be pushed!',
    'Blundered? Breathe. Bots get nervous too.',
  ];

  Future<void> start(PlayerProfile player) async {
    if (_phase == SearchPhase.searching) return;
    _phase = SearchPhase.searching;
    _bot = null;
    _preview = null;
    _elapsed = Duration.zero;
    _cancelled = false;
    _ticker?.cancel();
    final started = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed) return;
      _elapsed = DateTime.now().difference(started);
      notifyListeners();
    });
    notifyListeners();

    BotProfile found;
    try {
      found = await _source.findOpponent(player: player);
    } catch (_) {
      // Online sources can fail: always fall back to an offline bot.
      found = BotGenerator().generate(
        playerRating: player.rating,
        winStreak: player.winStreak,
        lossStreak: player.lossStreak,
      );
    }
    if (_cancelled || _disposed) return;
    _ticker?.cancel();
    _bot = found;
    _preview = EloService.preview(
      playerRating: player.rating,
      botRating: found.rating,
      gamesPlayed: player.gamesPlayed,
    );
    _phase = SearchPhase.found;
    notifyListeners();
  }

  void cancel() {
    _cancelled = true;
    _ticker?.cancel();
    _phase = SearchPhase.idle;
    _bot = null;
    _preview = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
