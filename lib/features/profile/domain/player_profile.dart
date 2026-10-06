import 'package:hive/hive.dart';

/// Offline player profile. Rating starts at 1000 ELO.
class PlayerProfile extends HiveObject {
  String name;
  int rating;
  int gamesPlayed;
  int wins;
  int losses;
  int draws;
  int bestRating;
  int winStreak;
  int lossStreak;
  int bestWinStreak;
  String avatarSeed;
  DateTime createdAt;
  String boardThemeId;
  String pieceStyle;

  PlayerProfile({
    required this.name,
    required this.rating,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.bestRating,
    required this.winStreak,
    required this.lossStreak,
    required this.bestWinStreak,
    required this.avatarSeed,
    required this.createdAt,
    this.boardThemeId = 'wood',
    this.pieceStyle = 'modern',
  });

  factory PlayerProfile.fresh({String? name, String? avatarSeed}) {
    final now = DateTime.now();
    return PlayerProfile(
      name: name ?? 'Player',
      rating: 1000,
      gamesPlayed: 0,
      wins: 0,
      losses: 0,
      draws: 0,
      bestRating: 1000,
      winStreak: 0,
      lossStreak: 0,
      bestWinStreak: 0,
      avatarSeed: avatarSeed ?? 'arena-player-${now.millisecondsSinceEpoch}',
      createdAt: now,
    );
  }

  double get winRate {
    if (gamesPlayed == 0) return 0;
    return wins / gamesPlayed;
  }
}

class PlayerProfileAdapter extends TypeAdapter<PlayerProfile> {
  static const int kTypeId = 11;

  @override
  int get typeId => kTypeId;

  @override
  PlayerProfile read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return PlayerProfile(
      name: fields[0] as String? ?? 'Player',
      rating: fields[1] as int? ?? 1000,
      gamesPlayed: fields[2] as int? ?? 0,
      wins: fields[3] as int? ?? 0,
      losses: fields[4] as int? ?? 0,
      draws: fields[5] as int? ?? 0,
      bestRating: fields[6] as int? ?? 1000,
      winStreak: fields[7] as int? ?? 0,
      lossStreak: fields[8] as int? ?? 0,
      bestWinStreak: fields[9] as int? ?? 0,
      avatarSeed: fields[10] as String? ?? 'arena-player',
      createdAt: fields[11] as DateTime? ?? DateTime.now(),
      boardThemeId: fields[12] as String? ?? 'wood',
      pieceStyle: fields[13] as String? ?? 'modern',
    );
  }

  @override
  void write(BinaryWriter writer, PlayerProfile obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.rating)
      ..writeByte(2)
      ..write(obj.gamesPlayed)
      ..writeByte(3)
      ..write(obj.wins)
      ..writeByte(4)
      ..write(obj.losses)
      ..writeByte(5)
      ..write(obj.draws)
      ..writeByte(6)
      ..write(obj.bestRating)
      ..writeByte(7)
      ..write(obj.winStreak)
      ..writeByte(8)
      ..write(obj.lossStreak)
      ..writeByte(9)
      ..write(obj.bestWinStreak)
      ..writeByte(10)
      ..write(obj.avatarSeed)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.boardThemeId)
      ..writeByte(13)
      ..write(obj.pieceStyle);
  }
}
