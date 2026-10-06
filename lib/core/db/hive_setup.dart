import 'package:hive_flutter/hive_flutter.dart';

import '../../features/profile/domain/game_record.dart';
import '../../features/profile/domain/player_profile.dart';

/// Hive bootstrap. All adapters are hand-written (no build_runner needed).
class HiveSetup {
  HiveSetup._();

  static const String profileBox = 'arena_profile';
  static const String gamesBox = 'arena_games';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(PlayerProfileAdapter.kTypeId)) {
      Hive.registerAdapter(PlayerProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(GameRecordAdapter.kTypeId)) {
      Hive.registerAdapter(GameRecordAdapter());
    }
    await Hive.openBox<PlayerProfile>(profileBox);
    await Hive.openBox<GameRecord>(gamesBox);
  }
}
