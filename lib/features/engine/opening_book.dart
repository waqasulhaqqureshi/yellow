import 'dart:math';

import '../bot/domain/bot_personality.dart';

/// Small human-like opening book (UCI, White first). The bot plays Black, so
/// book replies are the even-indexed plies. Every candidate is validated
/// against the engine's legal move generator before it is played.
///
/// Each personality has its own repertoire (line indices into [lines]) so
/// opponents feel distinct from move 1: the salty/trickster bots drag you
/// into sharp gambits, the formal/positional bot grinds you in a London,
/// the calm bot prefers solid classical structures.
class OpeningBook {
  OpeningBook._();

  static const Map<BotPersonality, List<int>> personaRepertoire = {
    // Sharp, open, gambit-flavoured: Scotch, Sicilians, Scandinavian,
    // Alekhine, King's Indian.
    BotPersonality.aggressive: [2, 3, 4, 7, 9, 13, 0],
    // System players: London, QGD/Slav structures, English, Reti, KIA.
    BotPersonality.positional: [14, 10, 11, 12, 15, 16, 17, 1],
    // Offbeat and provoking: Alekhine, Pirc, Scandinavian, QGA, Scotch.
    BotPersonality.trickster: [9, 8, 7, 12, 2],
    // Solid classical: French, Caro-Kann, QGD, Slav, London.
    BotPersonality.calm: [5, 6, 10, 11, 14],
    // Crowd-pleasing open games: Italian, Scotch, KID, Najdorf, Alekhine.
    BotPersonality.showman: [0, 2, 13, 3, 9],
  };

  /// The book lines this personality actually plays.
  static List<List<String>> linesFor(BotPersonality p) =>
      [for (final i in personaRepertoire[p] ?? const [0, 1]) lines[i]];

  static const List<List<String>> lines = [
    // Italian Game
    [
      'e2e4',
      'e7e5',
      'g1f3',
      'b8c6',
      'f1c4',
      'f8c5',
      'c2c3',
      'g8f6',
      'd2d4',
      'e5d4',
    ],
    // Ruy Lopez
    [
      'e2e4',
      'e7e5',
      'g1f3',
      'b8c6',
      'f1b5',
      'a7a6',
      'b5a4',
      'g8f6',
      'e1g1',
      'f8e7',
    ],
    // Scotch Game
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'd2d4', 'e5d4', 'f3d4', 'g8f6'],
    // Sicilian Najdorf
    [
      'e2e4',
      'c7c5',
      'g1f3',
      'd7d6',
      'd2d4',
      'c5d4',
      'f3d4',
      'g8f6',
      'b1c3',
      'a7a6',
    ],
    // Sicilian Classical
    [
      'e2e4',
      'c7c5',
      'g1f3',
      'b8c6',
      'd2d4',
      'c5d4',
      'f3d4',
      'g8f6',
      'b1c3',
      'e7e5',
    ],
    // French Defence
    ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3', 'f8b4', 'e4e5', 'c7c5'],
    // Caro-Kann
    ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'b1c3', 'd5e4', 'c3e4', 'c8f5'],
    // Scandinavian
    ['e2e4', 'd7d5', 'e4d5', 'd8d5', 'b1c3', 'd5a5', 'd2d4', 'g8f6'],
    // Pirc Defence
    ['e2e4', 'd7d6', 'd2d4', 'g8f6', 'b1c3', 'g7g6', 'f1c4', 'f8g7'],
    // Alekhine Defence
    ['e2e4', 'g8f6', 'e4e5', 'f6d5', 'd2d4', 'd7d6', 'g1f3', 'c8g4'],
    // Queen's Gambit Declined
    ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'b1c3', 'g8f6', 'c1g5', 'f8e7'],
    // Slav Defence
    ['d2d4', 'd7d5', 'c2c4', 'c7c6', 'g1f3', 'g8f6', 'b1c3', 'd5c4'],
    // Queen's Gambit Accepted
    ['d2d4', 'd7d5', 'c2c4', 'd5c4', 'g1f3', 'g8f6', 'e2e3', 'e7e6'],
    // King's Indian Defence
    ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3', 'f8g7', 'e2e4', 'd7d6'],
    // London System vs d5
    ['d2d4', 'd7d5', 'c1f4', 'g8f6', 'e2e3', 'e7e6', 'g1f3', 'f8d6'],
    // English Opening
    ['c2c4', 'e7e5', 'b1c3', 'g8f6', 'g1f3', 'b8c6', 'd2d4', 'e5d4'],
    // Reti Opening
    ['g1f3', 'd7d5', 'g2g3', 'g8f6', 'f1g2', 'e7e6', 'e1g1', 'f8e7'],
    // King's Indian Attack vs French setup
    ['e2e4', 'e7e6', 'd2d3', 'd7d5', 'b1d2', 'g8f6', 'g1f3', 'b8c6'],
  ];

  /// Returns the bot (Black) reply UCI when [historyUci] matches a known
  /// line prefix and we are still inside the book. Null when out of book.
  static String? replyFor({
    required List<String> historyUci,
    required int maxPly,
    required Random random,
    List<List<String>>? pool,
  }) {
    // Bot (Black) moves on odd history lengths (White just moved).
    if (historyUci.length.isEven) return null;
    if (historyUci.length >= maxPly) return null;
    final candidates = <String>[];
    for (final line in (pool ?? lines)) {
      if (line.length <= historyUci.length) continue;
      var matches = true;
      for (var i = 0; i < historyUci.length; i++) {
        if (line[i] != historyUci[i]) {
          matches = false;
          break;
        }
      }
      if (matches) candidates.add(line[historyUci.length]);
    }
    if (candidates.isEmpty) return null;
    return candidates[random.nextInt(candidates.length)];
  }

  /// Is [candidateUci] a known theoretical continuation after [historyUci]?
  /// Used to tag human moves as book moves (no blunder flag in the opening).
  static bool isKnownMove({
    required List<String> historyUci,
    required String candidateUci,
  }) {
    if (historyUci.length >= 12) return false;
    for (final line in lines) {
      if (line.length <= historyUci.length) continue;
      var matches = true;
      for (var i = 0; i < historyUci.length; i++) {
        if (line[i] != historyUci[i]) {
          matches = false;
          break;
        }
      }
      if (matches && line[historyUci.length] == candidateUci) return true;
    }
    return false;
  }
}
