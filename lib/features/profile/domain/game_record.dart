import 'package:hive/hive.dart';

import '../../game/domain/game_result.dart';

/// One finished game, stored for history + stats.
class GameRecord extends HiveObject {
  final String id;
  final DateTime playedAt;
  final String botName;
  final String botIso;
  final int botRating;
  final GameResult result;
  final int eloBefore;
  final int eloAfter;
  final int moves;
  final int userBlunders;
  final int? userAccuracy;
  final int? botAccuracy;
  final int userMistakes;
  final int userInaccuracies;
  final int userChecks;
  final int botBlunders;
  final int botMistakes;
  final int botInaccuracies;
  final int botChecks;

  GameRecord({
    required this.id,
    required this.playedAt,
    required this.botName,
    required this.botIso,
    required this.botRating,
    required this.result,
    required this.eloBefore,
    required this.eloAfter,
    required this.moves,
    required this.userBlunders,
    this.userAccuracy,
    this.botAccuracy,
    this.userMistakes = 0,
    this.userInaccuracies = 0,
    this.userChecks = 0,
    this.botBlunders = 0,
    this.botMistakes = 0,
    this.botInaccuracies = 0,
    this.botChecks = 0,
  });

  int get eloDelta => eloAfter - eloBefore;
}

class GameRecordAdapter extends TypeAdapter<GameRecord> {
  static const int kTypeId = 12;

  @override
  int get typeId => kTypeId;

  @override
  GameRecord read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }
    final resultIndex = fields[5] as int? ?? 2;
    final safeIndex =
        resultIndex >= 0 && resultIndex < GameResult.values.length
            ? resultIndex
            : 2;
    return GameRecord(
      id: fields[0] as String? ?? '',
      playedAt: fields[1] as DateTime? ?? DateTime.now(),
      botName: fields[2] as String? ?? 'Bot',
      botIso: fields[3] as String? ?? 'US',
      botRating: fields[4] as int? ?? 1000,
      result: GameResult.values[safeIndex],
      eloBefore: fields[6] as int? ?? 1000,
      eloAfter: fields[7] as int? ?? 1000,
      moves: fields[8] as int? ?? 0,
      userBlunders: fields[9] as int? ?? 0,
      userAccuracy: fields[10] as int?,
      botAccuracy: fields[11] as int?,
      userMistakes: fields[12] as int? ?? 0,
      userInaccuracies: fields[13] as int? ?? 0,
      userChecks: fields[14] as int? ?? 0,
      botBlunders: fields[15] as int? ?? 0,
      botMistakes: fields[16] as int? ?? 0,
      botInaccuracies: fields[17] as int? ?? 0,
      botChecks: fields[18] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, GameRecord obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.playedAt)
      ..writeByte(2)
      ..write(obj.botName)
      ..writeByte(3)
      ..write(obj.botIso)
      ..writeByte(4)
      ..write(obj.botRating)
      ..writeByte(5)
      ..write(obj.result.index)
      ..writeByte(6)
      ..write(obj.eloBefore)
      ..writeByte(7)
      ..write(obj.eloAfter)
      ..writeByte(8)
      ..write(obj.moves)
      ..writeByte(9)
      ..write(obj.userBlunders)
      ..writeByte(10)
      ..write(obj.userAccuracy)
      ..writeByte(11)
      ..write(obj.botAccuracy)
      ..writeByte(12)
      ..write(obj.userMistakes)
      ..writeByte(13)
      ..write(obj.userInaccuracies)
      ..writeByte(14)
      ..write(obj.userChecks)
      ..writeByte(15)
      ..write(obj.botBlunders)
      ..writeByte(16)
      ..write(obj.botMistakes)
      ..writeByte(17)
      ..write(obj.botInaccuracies)
      ..writeByte(18)
      ..write(obj.botChecks);
  }
}
