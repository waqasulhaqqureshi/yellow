import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/db/hive_setup.dart';
import '../../game/domain/game_result.dart';
import '../domain/game_record.dart';
import '../domain/player_profile.dart';

/// Single source of truth for the offline profile + game history.
class ProfileRepository extends ChangeNotifier {
  static const String _key = 'me';
  final Random _random = Random();

  late Box<PlayerProfile> _profileBox;
  late Box<GameRecord> _gamesBox;
  late PlayerProfile _profile;
  bool _ready = false;

  bool get ready => _ready;

  PlayerProfile get profile => _profile;

  Future<void> load() async {
    _profileBox = Hive.box<PlayerProfile>(HiveSetup.profileBox);
    _gamesBox = Hive.box<GameRecord>(HiveSetup.gamesBox);
    final existing = _profileBox.get(_key);
    if (existing == null) {
      _profile = PlayerProfile.fresh(
        name: 'Player${1000 + _random.nextInt(9000)}',
        avatarSeed: 'arena-player-${_random.nextInt(1 << 30)}',
      );
      await _profileBox.put(_key, _profile);
    } else {
      _profile = existing;
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _profile.name = clean.length > 16 ? clean.substring(0, 16) : clean;
    await _profile.save();
    notifyListeners();
  }

  Future<void> rerollAvatar() async {
    _profile.avatarSeed = 'arena-player-${_random.nextInt(1 << 30)}';
    await _profile.save();
    notifyListeners();
  }

  Future<void> setBoardTheme(String id) async {
    _profile.boardThemeId = id;
    await _profile.save();
    notifyListeners();
  }

  Future<void> setPieceStyle(String style) async {
    _profile.pieceStyle = style;
    await _profile.save();
    notifyListeners();
  }

  /// Consecutive calendar days with at least one completed game, ending
  /// today or yesterday. A missed day resets the active streak.
  int get activeDayStreak {
    final playedDays = _gamesBox.values
        .map((game) => DateTime(
              game.playedAt.toLocal().year,
              game.playedAt.toLocal().month,
              game.playedAt.toLocal().day,
            ))
        .toSet();
    if (playedDays.isEmpty) return 0;

    final today = DateTime.now();
    var day = DateTime(today.year, today.month, today.day);
    if (!playedDays.contains(day)) {
      day = day.subtract(const Duration(days: 1));
      if (!playedDays.contains(day)) return 0;
    }

    var streak = 0;
    while (playedDays.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double? get averageAccuracy {
    final accuracies = _gamesBox.values
        .map((game) => game.userAccuracy)
        .whereType<int>()
        .toList();
    if (accuracies.isEmpty) return null;
    return accuracies.reduce((a, b) => a + b) / accuracies.length;
  }

  /// Rating after each of the last [n] games, oldest → newest.
  /// Drives the home-card sparkline.
  List<int> ratingHistory({int n = 20}) {
    final games = _gamesBox.values.toList()
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));
    final recent =
        games.length > n ? games.sublist(games.length - n) : games;
    return [for (final g in recent) g.eloAfter];
  }

  /// Applies a finished game to the profile and stores the record.
  Future<void> applyGameResult({
    required GameResult result,
    required int newRating,
    required GameRecord record,
  }) async {
    _profile.gamesPlayed += 1;
    switch (result) {
      case GameResult.win:
        _profile.wins += 1;
        _profile.winStreak += 1;
        _profile.lossStreak = 0;
        if (_profile.winStreak > _profile.bestWinStreak) {
          _profile.bestWinStreak = _profile.winStreak;
        }
        break;
      case GameResult.loss:
        _profile.losses += 1;
        _profile.lossStreak += 1;
        _profile.winStreak = 0;
        break;
      case GameResult.draw:
        _profile.draws += 1;
        _profile.winStreak = 0;
        _profile.lossStreak = 0;
        break;
    }
    _profile.rating = newRating < 100 ? 100 : newRating;
    if (_profile.rating > _profile.bestRating) {
      _profile.bestRating = _profile.rating;
    }
    await _profile.save();
    await _gamesBox.put(record.id, record);
    // Trim history to the last 100 games.
    if (_gamesBox.length > 100) {
      final keys = _gamesBox.keys.whereType<String>().toList()..sort();
      if (keys.isNotEmpty) {
        await _gamesBox.delete(keys.first);
      }
    }
    notifyListeners();
  }

  List<GameRecord> recentGames({int limit = 10}) {
    final all = _gamesBox.values.toList();
    all.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    if (all.length <= limit) return all;
    return all.sublist(0, limit);
  }

  Future<void> resetAll() async {
    await _gamesBox.clear();
    _profile = PlayerProfile.fresh();
    await _profileBox.put(_key, _profile);
    notifyListeners();
  }
}
