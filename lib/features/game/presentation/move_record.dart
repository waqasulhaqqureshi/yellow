import 'package:genetom_chess_engine/genetom_chess_engine.dart';

import '../../engine/move_quality.dart';

/// One played move, for the move strip.
class MoveRecord {
  final MovesModel move;
  final String uci;
  final String label;
  final String glyph;
  final bool byHuman;

  /// Human moves only (drives the ?? / ? / ?! badges).
  final MoveVerdict? verdict;

  const MoveRecord({
    required this.move,
    required this.uci,
    required this.label,
    required this.glyph,
    required this.byHuman,
    this.verdict,
  });
}
