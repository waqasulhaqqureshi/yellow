import 'package:flutter/material.dart';
import 'package:genetom_chess_engine/genetom_chess_engine.dart';

import '../../../../core/theme/arena_theme.dart';
import '../../../../core/theme/board_themes.dart';
import '../../../../core/widgets/chess_piece_image.dart';

/// Tap-to-move board. Highlights selection, legal targets, last move and
/// check. Human-white orientation (v1).
class ChessBoardWidget extends StatelessWidget {
  final List<List<int>> board;
  final CellPosition? selected;
  final List<CellPosition> validTargets;
  final MovesModel? lastMove;
  final bool humanInCheck;
  final bool botInCheck;
  final bool animatePieces;
  final String boardThemeId;
  final String pieceStyle;
  final void Function(int row, int col) onTap;

  const ChessBoardWidget({
    super.key,
    required this.board,
    required this.selected,
    required this.validTargets,
    required this.lastMove,
    required this.humanInCheck,
    required this.botInCheck,
    this.animatePieces = true,
    this.boardThemeId = 'wood',
    this.pieceStyle = 'modern',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black54),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) =>
              _square(context, index ~/ 8, index % 8),
        ),
      ),
    );
  }

  Widget _square(BuildContext context, int row, int col) {
    final boardTheme = boardThemeFor(boardThemeId);
    final baseLight = (row + col).isEven;
    Color color = baseLight ? boardTheme.lightSquare : boardTheme.darkSquare;
    final v = board[row][col];

    final lm = lastMove;
    if (lm != null &&
        ((lm.currentPosition.row == row && lm.currentPosition.col == col) ||
            (lm.targetPosition.row == row && lm.targetPosition.col == col))) {
      color = Color.lerp(
        color,
        ArenaTheme.selectSquare,
        baseLight ? 0.48 : 0.38,
      )!;
    }

    final sel = selected;
    if (sel != null && sel.row == row && sel.col == col) {
      color = Color.lerp(color, ArenaTheme.selectSquare, 0.65) ?? color;
    }

    final inCheckSquare = (v == kingPower && humanInCheck) ||
        (v == -kingPower && botInCheck);
    if (inCheckSquare) {
      color = Color.lerp(color, ArenaTheme.checkSquare, 0.8) ?? color;
    }

    var isTarget = false;
    for (final t in validTargets) {
      if (t.row == row && t.col == col) {
        isTarget = true;
        break;
      }
    }

    return GestureDetector(
      onTap: () => onTap(row, col),
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, 0.055)!,
              Color.lerp(color, Colors.black, 0.035)!,
            ],
          ),
        ),
        child: Stack(
          children: [
            if (col == 0)
              Positioned(
                left: 3,
                top: 1,
                child: Text(
                  '${8 - row}',
                  style: _coordStyle(baseLight, boardTheme),
                ),
              ),
            if (row == 7)
              Positioned(
                right: 3,
                bottom: 1,
                child: Text(
                  String.fromCharCode(97 + col),
                  style: _coordStyle(baseLight, boardTheme),
                ),
              ),
            Center(child: _piece(v)),
            if (isTarget && v == 0)
              Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (isTarget && v != 0)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.35),
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }

  TextStyle _coordStyle(bool baseLight, BoardThemeOption boardTheme) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      color: baseLight
          ? boardTheme.darkSquare
          : boardTheme.lightSquare,
    );
  }

  Widget _piece(int value) {
    return AnimatedSwitcher(
      duration: animatePieces
          ? const Duration(milliseconds: 180)
          : Duration.zero,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: value == 0
          ? const SizedBox.shrink(key: ValueKey<int>(0))
          : FractionallySizedBox(
              key: ValueKey<int>(value),
              widthFactor: 0.95,
              heightFactor: 0.95,
              child: ChessPieceImage(value: value, style: pieceStyle),
            ),
    );
  }
}
