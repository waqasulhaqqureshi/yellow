import 'package:genetom_chess_engine/genetom_chess_engine.dart';

/// Lightweight board analysis: static evaluation, attack / check detection.
/// All scores are White-perspective centipawns. Human-white orientation (v1).
class ChessEval {
  ChessEval._();

  static List<List<int>> copyBoard(List<List<int>> board) {
    return [for (final row in board) List<int>.of(row)];
  }

  static int materialWhiteCp(List<List<int>> board) {
    var score = 0;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        score += board[r][c];
      }
    }
    return score;
  }

  /// Material + piece-square tables (reuses the engine's own tables).
  static double evaluateWhite(List<List<int>> board) {
    var score = 0.0;
    final endgame = _isEndgame(board);
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final v = board[r][c];
        if (v == 0) continue;
        final white = v > 0;
        final abs = v.abs();
        score += v; // material (values are signed already)
        final table = _tableFor(abs, endgame);
        if (table != null) {
          final bonus = white ? table[r][c] : table[7 - r][c];
          score += white ? bonus : -bonus;
        }
      }
    }
    return score;
  }

  static List<List<double>>? _tableFor(int absPiece, bool endgame) {
    if (absPiece == pawnPower) return pawnSquareTable;
    if (absPiece == horsePower) return horseSquareTable;
    if (absPiece == bishopPower) return bishopSquareTable;
    if (absPiece == rookPower) return rookSquareTable;
    if (absPiece == queenPower) return queenSquareTable;
    if (absPiece == kingPower) {
      return endgame ? kingEndGameSquareTable : kingMidGameSquareTable;
    }
    return null;
  }

  /// Public endgame detector (used by the human-behavior layer).
  static bool isEndgameBoard(List<List<int>> board) => _isEndgame(board);

  static bool _isEndgame(List<List<int>> board) {
    var queens = 0;
    var minors = 0;
    for (final row in board) {
      for (final v in row) {
        if (v.abs() == queenPower) queens++;
        if (v.abs() == horsePower || v.abs() == bishopPower) minors++;
      }
    }
    return queens == 0 || (queens <= 2 && minors <= 4);
  }

  static CellPosition? findKing(List<List<int>> board, bool white) {
    final target = white ? kingPower : -kingPower;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (board[r][c] == target) return CellPosition(row: r, col: c);
      }
    }
    return null;
  }

  static bool isInCheck(List<List<int>> board, bool whiteKing) {
    final king = findKing(board, whiteKing);
    if (king == null) return false;
    return isSquareAttacked(board, king.row, king.col, !whiteKing);
  }

  /// Is (row, col) attacked by [byWhite]'s pieces?
  static bool isSquareAttacked(
    List<List<int>> board,
    int row,
    int col,
    bool byWhite,
  ) {
    // Pawns: white pawns attack upwards (decreasing row).
    if (byWhite) {
      if (row + 1 < 8) {
        if (col - 1 >= 0 && board[row + 1][col - 1] == pawnPower) return true;
        if (col + 1 < 8 && board[row + 1][col + 1] == pawnPower) return true;
      }
    } else {
      if (row - 1 >= 0) {
        if (col - 1 >= 0 && board[row - 1][col - 1] == -pawnPower) return true;
        if (col + 1 < 8 && board[row - 1][col + 1] == -pawnPower) return true;
      }
    }
    // Knights.
    const knightSteps = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];
    final knight = byWhite ? horsePower : -horsePower;
    for (final s in knightSteps) {
      final r = row + s[0];
      final c = col + s[1];
      if (r >= 0 && r < 8 && c >= 0 && c < 8 && board[r][c] == knight) {
        return true;
      }
    }
    // King.
    final king = byWhite ? kingPower : -kingPower;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr;
        final c = col + dc;
        if (r >= 0 && r < 8 && c >= 0 && c < 8 && board[r][c] == king) {
          return true;
        }
      }
    }
    // Orthogonal sliders (rook / queen).
    const ortho = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    for (final d in ortho) {
      var r = row + d[0];
      var c = col + d[1];
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final v = board[r][c];
        if (v != 0) {
          if (byWhite && (v == rookPower || v == queenPower)) return true;
          if (!byWhite && (v == -rookPower || v == -queenPower)) return true;
          break;
        }
        r += d[0];
        c += d[1];
      }
    }
    // Diagonal sliders (bishop / queen).
    const diag = [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ];
    for (final d in diag) {
      var r = row + d[0];
      var c = col + d[1];
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final v = board[r][c];
        if (v != 0) {
          if (byWhite && (v == bishopPower || v == queenPower)) return true;
          if (!byWhite && (v == -bishopPower || v == -queenPower)) {
            return true;
          }
          break;
        }
        r += d[0];
        c += d[1];
      }
    }
    return false;
  }
}
