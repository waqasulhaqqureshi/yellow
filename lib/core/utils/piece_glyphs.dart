import 'package:genetom_chess_engine/genetom_chess_engine.dart';

/// Interprets `genetom_chess_engine` board integers.
///
/// Engine contract (verified against package source v0.0.4):
/// * Positive value => White piece, negative => Black piece, 0 => empty.
/// * `abs(value)` identifies the type: pawn=100, horse(knight)=320,
///   bishop=330, rook=500, queen=900, king=20000.
/// * v1: the human always plays White, so row 0 == rank 8, col 0 == file a.
class PieceGlyphs {
  PieceGlyphs._();

  /// Filled glyphs for both colours; colour is applied via TextStyle.
  static const Map<int, String> glyphByPower = {
    kingPower: '♚',
    queenPower: '♛',
    rookPower: '♜',
    bishopPower: '♝',
    horsePower: '♞',
    pawnPower: '♟',
  };

  static const Map<int, String> nameByPower = {
    kingPower: 'King',
    queenPower: 'Queen',
    rookPower: 'Rook',
    bishopPower: 'Bishop',
    horsePower: 'Knight',
    pawnPower: 'Pawn',
  };

  static const Map<int, String> assetByPower = {
    kingPower: 'assets/chess/pieces/king.png',
    queenPower: 'assets/chess/pieces/queen.png',
    rookPower: 'assets/chess/pieces/rook.png',
    bishopPower: 'assets/chess/pieces/bishop.png',
    horsePower: 'assets/chess/pieces/knight.png',
    pawnPower: 'assets/chess/pieces/pawn.png',
  };

  static const Map<int, String> fileByPower = {
    kingPower: 'king.png',
    queenPower: 'queen.png',
    rookPower: 'rook.png',
    bishopPower: 'bishop.png',
    horsePower: 'knight.png',
    pawnPower: 'pawn.png',
  };

  static const Map<int, String> shortByPower = {
    kingPower: 'K',
    queenPower: 'Q',
    rookPower: 'R',
    bishopPower: 'B',
    horsePower: 'N',
    pawnPower: '',
  };

  static bool isWhite(int v) => v > 0;

  static bool isEmpty(int v) => v == 0;

  static String glyphFor(int v) {
    if (v == 0) return '';
    return glyphByPower[v.abs()] ?? '';
  }

  static String assetFor(int v, {bool modern = true}) {
    final file = fileByPower[v.abs()] ?? 'pawn.png';
    if (modern) {
      final side = v < 0 ? 'new black' : 'new white';
      return 'new pieces/$side/$file';
    }
    return assetByPower[v.abs()] ?? 'assets/chess/pieces/pawn.png';
  }

  static String nameFor(int v) {
    if (v == 0) return 'Empty';
    return nameByPower[v.abs()] ?? 'Piece';
  }

  /// All bundled marble (modern) piece asset paths — white + black.
  /// Used by [PieceAssetPreloader] so the first painted move never flashes
  /// the glyph fallback while the bundle lazy-decodes an image.
  static List<String> modernAssetPaths() {
    final powers = <int>[
      kingPower,
      queenPower,
      rookPower,
      bishopPower,
      horsePower,
      pawnPower,
    ];
    return [
      for (final p in powers) assetFor(p, modern: true),
      for (final p in powers) assetFor(-p, modern: true),
    ];
  }

  /// All bundled classic silhouette asset paths (fallback / classic style).
  static List<String> classicAssetPaths() {
    final powers = <int>[
      kingPower,
      queenPower,
      rookPower,
      bishopPower,
      horsePower,
      pawnPower,
    ];
    return [
      for (final p in powers) assetFor(p, modern: false),
      for (final p in powers) assetFor(-p, modern: false),
    ];
  }

  /// 'e2' style square name. Assumes human-white orientation (v1).
  static String squareName(int row, int col) {
    if (row < 0 || row > 7 || col < 0 || col > 7) return '--';
    final file = String.fromCharCode(97 + col);
    final rank = 8 - row;
    return '$file$rank';
  }

  static String uciFor(MovesModel m) {
    return squareName(m.currentPosition.row, m.currentPosition.col) +
        squareName(m.targetPosition.row, m.targetPosition.col);
  }

  static MovesModel? moveFromUci(String uci) {
    try {
      if (uci.length < 4) return null;
      final f1 = uci.codeUnitAt(0) - 97;
      final r1 = 8 - int.parse(uci[1]);
      final f2 = uci.codeUnitAt(2) - 97;
      final r2 = 8 - int.parse(uci[3]);
      if (f1 < 0 || f1 > 7 || f2 < 0 || f2 > 7) return null;
      if (r1 < 0 || r1 > 7 || r2 < 0 || r2 > 7) return null;
      return MovesModel(
        currentPosition: CellPosition(row: r1, col: f1),
        targetPosition: CellPosition(row: r2, col: f2),
      );
    } catch (_) {
      return null;
    }
  }

  /// Short human label like 'Nf3' / 'exd5' / 'O-O'. Needs the board BEFORE
  /// the move is applied.
  static String prettyMove(MovesModel m, List<List<int>> boardBefore) {
    try {
      final piece = boardBefore[m.currentPosition.row][m.currentPosition.col];
      final target = boardBefore[m.targetPosition.row][m.targetPosition.col];
      final isCapture = target != 0;
      final short = shortByPower[piece.abs()] ?? '';
      final dest = squareName(m.targetPosition.row, m.targetPosition.col);
      // Castling detection.
      if (piece.abs() == kingPower &&
          (m.currentPosition.col - m.targetPosition.col).abs() == 2) {
        return m.targetPosition.col > m.currentPosition.col ? 'O-O' : 'O-O-O';
      }
      if (short.isEmpty) {
        // Pawn.
        if (isCapture) {
          final file = String.fromCharCode(97 + m.currentPosition.col);
          return '${file}x$dest';
        }
        return dest;
      }
      return isCapture ? '${short}x$dest' : '$short$dest';
    } catch (_) {
      return uciFor(m);
    }
  }
}
