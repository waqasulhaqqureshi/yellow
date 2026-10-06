import '../persona/chat_persona.dart';

/// One member of a group chat room (a persona-driven simulated player).
class GroupMember {
  final String name;
  final String avatarSeed;
  final String isoCode;
  final ChatStyle style;

  const GroupMember({
    required this.name,
    required this.avatarSeed,
    required this.isoCode,
    required this.style,
  });
}

/// A single message shown in a room.
class GroupMessage {
  final String senderName;
  final String? senderSeed;
  final String? isoCode;
  final String text;
  final bool isUser;

  const GroupMessage({
    required this.senderName,
    required this.text,
    this.senderSeed,
    this.isoCode,
    this.isUser = false,
  });
}

/// A discoverable group with a dominant conversation topic that maps to a
/// [GroupCorpus] pool key.
class ChatGroup {
  final String id;
  final String name;
  final String tagline;
  final String topic;
  final List<GroupMember> members;

  /// Ambient message gap range in seconds (bursty human rhythm).
  final int minGapSec;
  final int maxGapSec;

  const ChatGroup({
    required this.id,
    required this.name,
    required this.tagline,
    required this.topic,
    required this.members,
    this.minGapSec = 7,
    this.maxGapSec = 20,
  });

  int get memberCount => members.length + 120; // + lurkers for flavour.
}

/// The catalog shown in the explore screen.
class GroupCatalog {
  GroupCatalog._();

  static const List<ChatGroup> groups = [
    ChatGroup(
      id: 'blitz-addicts',
      name: 'Blitz Addicts',
      tagline: '3+2 or nothing. Flags are a lifestyle.',
      topic: 'chessTalk',
      minGapSec: 5,
      maxGapSec: 14,
      members: [
        GroupMember(name: 'FlagHunter88', avatarSeed: 'g1', isoCode: 'PK', style: ChatStyle.rash),
        GroupMember(name: 'PremovieQueen', avatarSeed: 'g2', isoCode: 'IN', style: ChatStyle.cheerful),
        GroupMember(name: 'TimeScramble', avatarSeed: 'g3', isoCode: 'GB', style: ChatStyle.salty),
        GroupMember(name: 'BulletBhai', avatarSeed: 'g4', isoCode: 'PK', style: ChatStyle.normal),
        GroupMember(name: 'ClockWatcher', avatarSeed: 'g5', isoCode: 'US', style: ChatStyle.silent),
      ],
    ),
    ChatGroup(
      id: 'karachi-chess-club',
      name: 'Karachi Chess Club',
      tagline: 'Chai, biryani and back-rank mates.',
      topic: 'foodTalk',
      members: [
        GroupMember(name: 'ChaiWalaChess', avatarSeed: 'k1', isoCode: 'PK', style: ChatStyle.friendly),
        GroupMember(name: 'BiryaniBias', avatarSeed: 'k2', isoCode: 'PK', style: ChatStyle.salty),
        GroupMember(name: 'CliftonKnight', avatarSeed: 'k3', isoCode: 'PK', style: ChatStyle.normal),
        GroupMember(name: 'NazimabadNajdorf', avatarSeed: 'k4', isoCode: 'PK', style: ChatStyle.formal),
        GroupMember(name: 'SeaViewRook', avatarSeed: 'k5', isoCode: 'PK', style: ChatStyle.cheerful),
        GroupMember(name: 'GulshanGambit', avatarSeed: 'k6', isoCode: 'PK', style: ChatStyle.rash),
      ],
    ),
    ChatGroup(
      id: 'beginner-lounge',
      name: 'Beginner Lounge',
      tagline: 'We hang queens here. Safest room on the app.',
      topic: 'questions',
      members: [
        GroupMember(name: 'NewbieNina', avatarSeed: 'b1', isoCode: 'CA', style: ChatStyle.friendly),
        GroupMember(name: 'LearningLad', avatarSeed: 'b2', isoCode: 'PK', style: ChatStyle.normal),
        GroupMember(name: 'FirstMoveFear', avatarSeed: 'b3', isoCode: 'BR', style: ChatStyle.silent),
        GroupMember(name: 'CoachKhan', avatarSeed: 'b4', isoCode: 'PK', style: ChatStyle.formal),
        GroupMember(name: 'EloClimber01', avatarSeed: 'b5', isoCode: 'EG', style: ChatStyle.cheerful),
      ],
    ),
    ChatGroup(
      id: 'endgame-grinders',
      name: 'Endgame Grinders',
      tagline: 'Rook endings are always drawn. Until they are not.',
      topic: 'endgameTalk',
      minGapSec: 9,
      maxGapSec: 24,
      members: [
        GroupMember(name: 'LucenaLord', avatarSeed: 'e1', isoCode: 'DE', style: ChatStyle.formal),
        GroupMember(name: 'PhilidorFan', avatarSeed: 'e2', isoCode: 'FR', style: ChatStyle.normal),
        GroupMember(name: 'PawnPusher', avatarSeed: 'e3', isoCode: 'PK', style: ChatStyle.rash),
        GroupMember(name: 'Opposition', avatarSeed: 'e4', isoCode: 'ES', style: ChatStyle.silent),
      ],
    ),
    ChatGroup(
      id: 'chess-memes',
      name: 'Chess Memes Only',
      tagline: 'Certified pre-blundered content.',
      topic: 'banter',
      minGapSec: 4,
      maxGapSec: 12,
      members: [
        GroupMember(name: 'MemeMachine', avatarSeed: 'm1', isoCode: 'US', style: ChatStyle.cheerful),
        GroupMember(name: 'SaltySniper', avatarSeed: 'm2', isoCode: 'PK', style: ChatStyle.salty),
        GroupMember(name: 'LolLord', avatarSeed: 'm3', isoCode: 'IN', style: ChatStyle.rash),
        GroupMember(name: 'DeadpanDora', avatarSeed: 'm4', isoCode: 'SE', style: ChatStyle.silent),
        GroupMember(name: 'BanterBaron', avatarSeed: 'm5', isoCode: 'GB', style: ChatStyle.normal),
      ],
    ),
    ChatGroup(
      id: 'night-owls',
      name: 'Night Owls Arena',
      tagline: '2am is a perfectly reasonable time for one more game.',
      topic: 'lifeTalk',
      minGapSec: 10,
      maxGapSec: 26,
      members: [
        GroupMember(name: 'InsomniacIM', avatarSeed: 'n1', isoCode: 'PK', style: ChatStyle.silent),
        GroupMember(name: 'MidnightMover', avatarSeed: 'n2', isoCode: 'AE', style: ChatStyle.normal),
        GroupMember(name: 'SleeplessInSindh', avatarSeed: 'n3', isoCode: 'PK', style: ChatStyle.salty),
        GroupMember(name: 'MoonlightMate', avatarSeed: 'n4', isoCode: 'TR', style: ChatStyle.friendly),
      ],
    ),
    ChatGroup(
      id: 'cricket-chai',
      name: 'Cricket + Chess Chai',
      tagline: 'Shaheen spells between scholar mates.',
      topic: 'sportTalk',
      members: [
        GroupMember(name: 'YorkerYork', avatarSeed: 'c1', isoCode: 'PK', style: ChatStyle.rash),
        GroupMember(name: 'CoverDriveCM', avatarSeed: 'c2', isoCode: 'PK', style: ChatStyle.cheerful),
        GroupMember(name: 'SpinWizard', avatarSeed: 'c3', isoCode: 'LK', style: ChatStyle.normal),
        GroupMember(name: 'DuckOutDinesh', avatarSeed: 'c4', isoCode: 'IN', style: ChatStyle.salty),
        GroupMember(name: 'GreenShirtGG', avatarSeed: 'c5', isoCode: 'PK', style: ChatStyle.friendly),
      ],
    ),
    ChatGroup(
      id: 'london-survivors',
      name: 'London System Survivors',
      tagline: 'Same 8 moves, every game, no shame.',
      topic: 'openingsTalk',
      minGapSec: 8,
      maxGapSec: 22,
      members: [
        GroupMember(name: 'LondonCalling', avatarSeed: 'l1', isoCode: 'GB', style: ChatStyle.formal),
        GroupMember(name: 'SystemPlayer', avatarSeed: 'l2', isoCode: 'US', style: ChatStyle.normal),
        GroupMember(name: 'Bf4Forever', avatarSeed: 'l3', isoCode: 'AU', style: ChatStyle.silent),
        GroupMember(name: 'AntiLondon', avatarSeed: 'l4', isoCode: 'PK', style: ChatStyle.salty),
      ],
    ),
    ChatGroup(
      id: 'queens-gambit-fans',
      name: "Queen's Gambit Fans",
      tagline: 'For people who learned chess from a TV show. Welcome home.',
      topic: 'openingsTalk',
      members: [
        GroupMember(name: 'BethWannabe', avatarSeed: 'q1', isoCode: 'US', style: ChatStyle.cheerful),
        GroupMember(name: 'D4Devotee', avatarSeed: 'q2', isoCode: 'RU', style: ChatStyle.formal),
        GroupMember(name: 'HarmonHero', avatarSeed: 'q3', isoCode: 'CA', style: ChatStyle.normal),
        GroupMember(name: 'CeilingGazer', avatarSeed: 'q4', isoCode: 'DE', style: ChatStyle.silent),
      ],
    ),
    ChatGroup(
      id: 'rating-climbers',
      name: 'Rating Climbers',
      tagline: 'From 3 losses to 3 wins. Mental.',
      topic: 'hype',
      members: [
        GroupMember(name: 'LadderGrinder', avatarSeed: 'r1', isoCode: 'PK', style: ChatStyle.rash),
        GroupMember(name: 'PlusTwelve', avatarSeed: 'r2', isoCode: 'IN', style: ChatStyle.cheerful),
        GroupMember(name: 'TiltProof', avatarSeed: 'r3', isoCode: 'BR', style: ChatStyle.salty),
        GroupMember(name: 'StreakKeeper', avatarSeed: 'r4', isoCode: 'NG', style: ChatStyle.normal),
        GroupMember(name: 'NewPB', avatarSeed: 'r5', isoCode: 'PH', style: ChatStyle.friendly),
      ],
    ),
    ChatGroup(
      id: 'casual-chatter',
      name: 'Casual Chatter',
      tagline: 'Chess sometimes. Vibes always.',
      topic: 'lifeTalk',
      minGapSec: 8,
      maxGapSec: 20,
      members: [
        GroupMember(name: 'VibeCheck', avatarSeed: 'v1', isoCode: 'MX', style: ChatStyle.cheerful),
        GroupMember(name: 'SlowSipper', avatarSeed: 'v2', isoCode: 'PK', style: ChatStyle.friendly),
        GroupMember(name: 'RandomRook', avatarSeed: 'v3', isoCode: 'ZA', style: ChatStyle.normal),
        GroupMember(name: 'QuietQueen', avatarSeed: 'v4', isoCode: 'JP', style: ChatStyle.silent),
        GroupMember(name: 'TopicHopper', avatarSeed: 'v5', isoCode: 'EG', style: ChatStyle.rash),
      ],
    ),
    ChatGroup(
      id: 'tactics-trainers',
      name: 'Tactics Trainers',
      tagline: 'Puzzles 1500, games 600. Make it make sense.',
      topic: 'chessTalk',
      minGapSec: 8,
      maxGapSec: 18,
      members: [
        GroupMember(name: 'PuzzlePete', avatarSeed: 't1', isoCode: 'US', style: ChatStyle.normal),
        GroupMember(name: 'ForkFinder', avatarSeed: 't2', isoCode: 'PK', style: ChatStyle.rash),
        GroupMember(name: 'MateInMissed', avatarSeed: 't3', isoCode: 'IN', style: ChatStyle.salty),
        GroupMember(name: 'PatternPal', avatarSeed: 't4', isoCode: 'VN', style: ChatStyle.friendly),
      ],
    ),
  ];

  static ChatGroup byId(String id) =>
      groups.firstWhere((g) => g.id == id, orElse: () => groups.first);
}
