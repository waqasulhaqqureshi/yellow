import 'package:genetom_chess_engine/genetom_chess_engine.dart';

import 'chess_eval.dart';

/// Internal control-flow exception: aborts the search when the time box or
/// node cap expires. The last fully completed iteration is always kept.
class _SearchTimeout implements Exception {
  const _SearchTimeout();
}

class ScoredMove {
  final MovesModel move;

  /// Score from the perspective of the side to move at the root.
  final double score;

  ScoredMove(this.move, this.score);
}

/// Time-boxed negamax search with alpha-beta pruning, MVV-LVA move ordering,
/// iterative deepening and a small captures-only quiescence.
///
/// Architecture note: legality ALWAYS comes from `genetom_chess_engine`'s
/// own move generator ([legalMovesFor]). The search only ever RETURNS moves
/// taken from that generator, so it can never produce an illegal move — the
/// worst case of any evaluation subtlety is a slightly weaker (but legal)
/// move. Strength is bounded by a hard time box + node cap, so slow devices
/// degrade gracefully instead of hanging.
class ArenaSearch {
  ArenaSearch({required this.legalMovesFor});

  /// Engine-backed legal move generator: (board, square) -> targets.
  final List<CellPosition> Function(List<List<int>> board, CellPosition pos)
      legalMovesFor;

  static const double mateScore = 100000.0;
  static const int maxNodes = 220000;

  int _nodes = 0;
  int _deadlineMs = 0;

  /// Searches the best move for the side to move with a [timeMs] budget.
  /// Returns scored root moves sorted best-first (empty if no legal moves).
  List<ScoredMove> search({
    required List<List<int>> board,
    required bool whiteToMove,
    required int timeMs,
    required int maxDepth,
  }) {
    _nodes = 0;
    final budget = timeMs < 80 ? 80 : timeMs;
    _deadlineMs = DateTime.now().millisecondsSinceEpoch + budget;

    final rootMoves = _allLegalMoves(board, whiteToMove);
    if (rootMoves.isEmpty) return <ScoredMove>[];
    if (rootMoves.length == 1) {
      return <ScoredMove>[ScoredMove(rootMoves.first, 0)];
    }

    _orderMoves(board, rootMoves);

    // Iterative deepening: each completed iteration re-orders the next one,
    // so an abort always leaves a fully-searched result.
    var completed = rootMoves.map((m) => ScoredMove(m, 0)).toList();
    try {
      for (var depth = 1; depth <= maxDepth; depth++) {
        final scored = <ScoredMove>[];
        var alpha = -double.infinity;
        for (var i = 0; i < completed.length; i++) {
          final move = completed[i].move;
          final child = ChessEval.copyBoard(board);
          _makeMove(child, move);
          final score = -_negamax(
            child,
            depth - 1,
            -double.infinity,
            -alpha,
            whiteToMove ? -1 : 1,
            1,
          );
          scored.add(ScoredMove(move, score));
          if (score > alpha) alpha = score;
        }
        scored.sort((a, b) => b.score.compareTo(a.score));
        completed = scored;
        if (depth >= 2) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now >= _deadlineMs - (budget ~/ 3)) break;
        }
      }
    } on _SearchTimeout {
      // Keep the last fully completed iteration.
    }
    return completed;
  }

  /// Negamax. Returns the score from [color]'s perspective (+1 white / -1
  /// black). [ply] counts down from the root for mate-distance scoring.
  double _negamax(
    List<List<int>> board,
    int depth,
    double alpha,
    double beta,
    int color,
    int ply,
  ) {
    _nodes++;
    _pollTimeout();
    if (depth <= 0) {
      return _quiescence(board, alpha, beta, color, 0);
    }
    final whiteToMove = color == 1;
    final moves = _allLegalMoves(board, whiteToMove);
    if (moves.isEmpty) {
      if (ChessEval.isInCheck(board, whiteToMove)) {
        return -mateScore + ply; // checkmated: prefer slower mates
      }
      return 0; // stalemate
    }
    _orderMoves(board, moves);
    var best = -double.infinity;
    for (final move in moves) {
      final child = ChessEval.copyBoard(board);
      _makeMove(child, move);
      final score = -_negamax(child, depth - 1, -beta, -alpha, -color, ply + 1);
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Captures-only extension at leaf nodes (calms the horizon effect).
  double _quiescence(
    List<List<int>> board,
    double alpha,
    double beta,
    int color,
    int qply,
  ) {
    _nodes++;
    _pollTimeout();
    final standPat = color * ChessEval.evaluateWhite(board);
    if (standPat >= beta) return beta;
    if (standPat > alpha) alpha = standPat;
    if (qply >= 2) return alpha;
    final whiteToMove = color == 1;
    final captures = _allLegalMoves(board, whiteToMove, capturesOnly: true);
    _orderMoves(board, captures);
    for (final move in captures) {
      final child = ChessEval.copyBoard(board);
      _makeMove(child, move);
      final score = -_quiescence(child, -beta, -alpha, -color, qply + 1);
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  void _pollTimeout() {
    if ((_nodes & 1023) == 0) {
      if (_nodes > maxNodes ||
          DateTime.now().millisecondsSinceEpoch >= _deadlineMs) {
        throw const _SearchTimeout();
      }
    }
  }

  List<MovesModel> _allLegalMoves(
    List<List<int>> board,
    bool whiteToMove, {
    bool capturesOnly = false,
  }) {
    final moves = <MovesModel>[];
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final v = board[r][c];
        if (v == 0) continue;
        if (whiteToMove && v < 0) continue;
        if (!whiteToMove && v > 0) continue;
        final from = CellPosition(row: r, col: c);
        List<CellPosition> targets;
        try {
          targets = legalMovesFor(board, from);
        } catch (_) {
          continue;
        }
        for (final t in targets) {
          if (capturesOnly && board[t.row][t.col] == 0) continue;
          moves.add(
            MovesModel(
              currentPosition: from,
              targetPosition: CellPosition(row: t.row, col: t.col),
            ),
          );
        }
      }
    }
    return moves;
  }

  /// Applies [move] on a private board copy. Handles castling (king slides
  /// two squares) and auto-queens promotions inside the search.
  void _makeMove(List<List<int>> board, MovesModel move) {
    final from = move.currentPosition;
    final to = move.targetPosition;
    final piece = board[from.row][from.col];
    if (piece.abs() == kingPower && (from.col - to.col).abs() == 2) {
      board[to.row][to.col] = piece;
      board[from.row][from.col] = emptyCellPower;
      if (to.col > from.col) {
        board[from.row][from.col + 1] = board[from.row][7];
        board[from.row][7] = emptyCellPower;
      } else {
        board[from.row][from.col - 1] = board[from.row][0];
        board[from.row][0] = emptyCellPower;
      }
      return;
    }
    board[to.row][to.col] = piece;
    board[from.row][from.col] = emptyCellPower;
    if (piece == pawnPower && to.row == 0) {
      board[to.row][to.col] = queenPower;
    } else if (piece == -pawnPower && to.row == 7) {
      board[to.row][to.col] = -queenPower;
    }
  }

  /// MVV-LVA ordering: most-valuable-victim first, least-valuable-attacker
  /// first. Ordering is what makes alpha-beta pruning effective.
  void _orderMoves(List<List<int>> board, List<MovesModel> moves) {
    int scoreOf(MovesModel m) {
      final victim = board[m.targetPosition.row][m.targetPosition.col].abs();
      final attacker =
          board[m.currentPosition.row][m.currentPosition.col].abs();
      return victim * 10 - (attacker ~/ 32);
    }

    moves.sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
  }

  /// Kept for diagnostics / future transposition table work.
  @override
  String toString() => 'ArenaSearch(nodes: $_nodes)';
}
